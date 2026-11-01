unit Raims.Http;

{$ZEROBASEDSTRINGS OFF}

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.JSON, System.Diagnostics,
  System.Net.HttpClient, Raims.Core;

type
  TRaimsHttpTransport = class(TInterfacedObject, IRaimsTransport)
  private
    FClient: THTTPClient;
    FClosed: Boolean;
    FLock: TObject;
    FStarted: TStopwatch;
    FTimeout: Integer;
    FResponseLimit: Integer;
    FAbortedForSize: Boolean;
    FAbortedForTime: Boolean;
    procedure ReceiveData(const Sender: TObject; AContentLength,
      AReadCount: Int64; var Abort: Boolean);
  public
    constructor Create;
    destructor Destroy; override;
    function Send(const Request: TRaimsHttpRequest): TRaimsHttpResponse;
    procedure Close;
  end;

  TRaimsRequestor = class(TInterfacedObject, IRaimsRequestor)
  private
    FApiKey: string;
    FOptions: TRaimsClientOptions;
    FTransport: IRaimsTransport;
    FLock: TObject;
    FClosed: Integer;
    FCloseEvent: TEvent;
    FNotifying: Boolean;
    procedure EnsureOpen;
    procedure Notify(const Method, PathTemplate: string; Attempt: Integer;
      const Started: TStopwatch; const Metadata: TRaimsResponseMetadata);
    function Interpret(const Response: TRaimsHttpResponse;
      const Metadata: TRaimsResponseMetadata;
      const SuccessStatuses: array of Integer): TRaimsResponse;
  public
    constructor Create(const ApiKey: string; const Options: TRaimsClientOptions;
      const Transport: IRaimsTransport = nil);
    destructor Destroy; override;
    function Request(const Method, PathTemplate, Path: string;
      Query, Body: TRaimsParams; const Options: TRaimsRequestOptions;
      const SuccessStatuses: array of Integer): TRaimsResponse;
    procedure Close;
    function IsClosed: Boolean;
  end;

implementation

uses
  System.Net.URLClient, System.RegularExpressions, System.DateUtils,
  System.Math, Raims.Constants;

type
  TBoundedResponseStream = class(TMemoryStream)
  private
    FLimit: Integer;
  public
    constructor Create(Limit: Integer);
    function Write(const Buffer; Count: Longint): Longint; override;
  end;

constructor TBoundedResponseStream.Create(Limit: Integer);
begin
  inherited Create;
  FLimit := Limit;
end;

function TBoundedResponseStream.Write(const Buffer; Count: Longint): Longint;
begin
  if (Count < 0) or (Position > Int64(FLimit) - Count) then
    raise ERaimsUnexpectedResponseError.Create('The API response exceeds the supported size.');
  Result := inherited Write(Buffer, Count);
end;

procedure ValidateHeaderInput(const Value, Description: string; AllowEmpty: Boolean);
var
  C: Char;
begin
  if not AllowEmpty and (Value = '') then
    raise EArgumentException.Create(Description + ' must not be empty.');
  for C in Value do
    if (Ord(C) <= 32) or (Ord(C) >= 127) then
      raise EArgumentException.Create(Description + ' must contain printable ASCII without spaces.');
end;

function ValidateBase(const Value: string): string;
var
  Match: TMatch;
  Port: Integer;
begin
  Match := TRegEx.Match(Value,
    '\A(https?)://([A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?|\[::1\])(?::([0-9]{1,5}))?/?\z',
    [roIgnoreCase]);
  if not Match.Success then
    raise EArgumentException.Create('ApiBase must be an HTTPS origin without credentials, path, query or fragment.');
  if SameText(Match.Groups[1].Value, 'http') and
    not SameText(Match.Groups[2].Value, 'localhost') and
    (Match.Groups[2].Value <> '127.0.0.1') and
    (Match.Groups[2].Value <> '[::1]') then
    raise EArgumentException.Create('HTTP is allowed only on loopback for local validation.');
  if Match.Groups[3].Value <> '' then
    if not TryStrToInt(Match.Groups[3].Value, Port) or (Port < 1) or (Port > 65535) then
      raise EArgumentException.Create('ApiBase contains an invalid port.');
  Result := Value;
  if Result[Length(Result)] = '/' then Delete(Result, Length(Result), 1);
end;

function EncodeQueryValue(const Value: string): string;
const
  Hex: string = '0123456789ABCDEF';
var
  B: Byte;
begin
  Result := '';
  for B in RaimsEncodeUtf8(Value) do
    if ((B >= Ord('a')) and (B <= Ord('z'))) or
       ((B >= Ord('A')) and (B <= Ord('Z'))) or
       ((B >= Ord('0')) and (B <= Ord('9'))) or
       (B = Ord('-')) or (B = Ord('_')) or (B = Ord('.')) or (B = Ord('~')) then
      Result := Result + Char(B)
    else
      Result := Result + '%' + Hex[(B shr 4) + 1] + Hex[(B and 15) + 1];
end;

procedure AppendQuery(var Text: string; const Name: string; const Value: TJSONValue);
begin
  if (Value is TJSONObject) or (Value is TJSONArray) or (Value is TJSONNull) then
    raise EArgumentException.Create('Query values must be scalar values or lists of scalar values.');
  if Text <> '' then Text := Text + '&';
  Text := Text + EncodeQueryValue(Name) + '=' + EncodeQueryValue(Value.Value);
end;

function BuildQuery(Params: TRaimsParams): string;
var
  Data: TJSONObject;
  Pair: TJSONPair;
  Item: TJSONValue;
begin
  Result := '';
  if Params = nil then Exit;
  if Params.HasField('after') and not Params.IsNull('after') and
     Params.HasField('before') and not Params.IsNull('before') then
    raise EArgumentException.Create('After and before cannot be used together.');
  Data := Params.RawJson;
  try
    for Pair in Data do
      if not (Pair.JsonValue is TJSONNull) then
      begin
        if Pair.JsonValue is TJSONArray then
          for Item in TJSONArray(Pair.JsonValue) do
            AppendQuery(Result, Pair.JsonString.Value, Item)
        else
          AppendQuery(Result, Pair.JsonString.Value, Pair.JsonValue);
      end;
  finally
    Data.Free;
  end;
end;

function CanRetryStatus(Status: Integer): Boolean;
begin
  Result := (Status = 408) or (Status = 429) or (Status = 500) or
    (Status = 502) or (Status = 503) or (Status = 504);
end;

procedure MergeResponseMetadata(const Available: TRaimsResponseMetadata;
  var Current: TRaimsResponseMetadata);
begin
  if Available.StatusCode <> 0 then Current.StatusCode := Available.StatusCode;
  if Available.RequestId <> '' then Current.RequestId := Available.RequestId;
  if Available.RetryAfter <> '' then Current.RetryAfter := Available.RetryAfter;
end;

function RetryDelay(Attempt: Integer; const RetryAfter: string): Integer;
var
  Seconds: Double;
  Settings: TFormatSettings;
  Stamp: TDateTime;
begin
  Result := Min(2000, 250 shl Min(Attempt - 1, 3));
  if RetryAfter = '' then Exit;
  Settings := TFormatSettings.Create;
  Settings.DecimalSeparator := '.';
  Settings.ThousandSeparator := #0;
  if not TryStrToFloat(RetryAfter, Seconds, Settings) then
  begin
    try
      Stamp := TTimeZone.Local.ToUniversalTime(Now);
      Seconds := (HTTPToDate(RetryAfter) - Stamp) * SecsPerDay;
    except
      on E: EConvertError do Exit;
      on E: EArgumentException do Exit;
    end;
  end;
  if IsNan(Seconds) or IsInfinite(Seconds) then Exit;
  if Seconds > 30 then Exit(-1);
  if Seconds > 0 then Result := Max(Result, Ceil(Seconds * 1000));
end;

constructor TRaimsHttpTransport.Create;
begin
  inherited Create;
  FLock := TObject.Create;
  FClient := THTTPClient.Create;
  FClient.HandleRedirects := False;
  FClient.AllowCookies := False;
  FClient.SecureProtocols := [THTTPSecureProtocol.TLS12];
  FClient.PreemptiveAuthentication := False;
  FClient.UseDefaultCredentials := False;
  FClient.OnReceiveData := ReceiveData;
end;

procedure TRaimsHttpTransport.ReceiveData(const Sender: TObject; AContentLength,
  AReadCount: Int64; var Abort: Boolean);
begin
  FAbortedForSize := FAbortedForSize or (AContentLength > FResponseLimit) or
    (AReadCount > FResponseLimit);
  FAbortedForTime := FAbortedForTime or
    (FStarted.ElapsedMilliseconds >= FTimeout);
  Abort := Abort or FAbortedForSize or FAbortedForTime;
end;

destructor TRaimsHttpTransport.Destroy;
begin
  Close;
  FLock.Free;
  inherited;
end;

procedure TRaimsHttpTransport.Close;
begin
  TMonitor.Enter(FLock);
  try
    if FClosed then Exit;
    FClosed := True;
    FreeAndNil(FClient);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRaimsHttpTransport.Send(const Request: TRaimsHttpRequest): TRaimsHttpResponse;
var
  Headers: TNetHeaders;
  Received: TNetHeaders;
  Source: TBytesStream;
  Target: TBoundedResponseStream;
  Response: IHTTPResponse;
  I: Integer;
begin
  TMonitor.Enter(FLock);
  try
    if FClosed then raise ERaimsConnectionError.Create('The API transport is closed.');
    FClient.ConnectionTimeout := Request.TimeoutMilliseconds;
    FClient.SendTimeout := Request.TimeoutMilliseconds;
    FClient.ResponseTimeout := Request.TimeoutMilliseconds;
    FStarted := TStopwatch.StartNew;
    FTimeout := Request.TimeoutMilliseconds;
    FResponseLimit := Request.MaxResponseBytes;
    FAbortedForSize := False;
    FAbortedForTime := False;
    SetLength(Headers, Length(Request.Headers));
    for I := 0 to High(Request.Headers) do
      Headers[I] := TNameValuePair.Create(Request.Headers[I].Name, Request.Headers[I].Value);
    Source := nil;
    Target := nil;
    try
      Source := TBytesStream.Create(RaimsEncodeUtf8(Request.Body));
      Target := TBoundedResponseStream.Create(Request.MaxResponseBytes);
      try
        Response := FClient.Execute(Request.Method, Request.Url, Source, Target, Headers) as IHTTPResponse;
      except
        on E: EOutOfMemory do raise;
        on E: EExternalException do raise;
        on E: Exception do
        begin
          if FAbortedForSize then
            raise ERaimsUnexpectedResponseError.Create('The API response exceeds the supported size.');
          if FAbortedForTime then
            raise ERaimsConnectionError.Create('The API response exceeded its receive deadline.');
          raise;
        end;
      end;
      if FAbortedForSize then
        raise ERaimsUnexpectedResponseError.Create('The API response exceeds the supported size.');
      if FAbortedForTime then
        raise ERaimsConnectionError.Create('The API response exceeded its receive deadline.');
      Result.StatusCode := Response.StatusCode;
      Received := Response.Headers;
      SetLength(Result.Headers, Length(Received));
      for I := 0 to High(Received) do
        Result.Headers[I] := TRaimsHeader.Create(Received[I].Name, Received[I].Value);
      SetLength(Result.Body, Target.Size);
      if Target.Size > 0 then Move(Target.Memory^, Result.Body[0], Target.Size);
    finally
      Response := nil;
      Target.Free;
      Source.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TRaimsRequestor.Create(const ApiKey: string; const Options: TRaimsClientOptions;
  const Transport: IRaimsTransport);
begin
  inherited Create;
  FLock := TObject.Create;
  FCloseEvent := TEvent.Create(nil, True, False, '');
  ValidateHeaderInput(ApiKey, 'API key', False);
  FApiKey := ApiKey;
  FOptions := Options;
  FOptions.ApiBase := ValidateBase(Options.ApiBase);
  if (Options.TimeoutMilliseconds < 1) or (Options.TimeoutMilliseconds > 300000) then
    raise EArgumentOutOfRangeException.Create('TimeoutMilliseconds must be between 1 and 300000.');
  if (Options.MaxNetworkRetries < 0) or (Options.MaxNetworkRetries > 5) then
    raise EArgumentOutOfRangeException.Create('MaxNetworkRetries must be between 0 and 5.');
  if (Options.MaxResponseBytes < 1) or (Options.MaxResponseBytes > 16 * 1024 * 1024) then
    raise EArgumentOutOfRangeException.Create('MaxResponseBytes must be between 1 and 16777216.');
  if Transport = nil then FTransport := TRaimsHttpTransport.Create
  else FTransport := Transport;
end;

destructor TRaimsRequestor.Destroy;
begin
  Close;
  FCloseEvent.Free;
  FLock.Free;
  inherited;
end;

function TRaimsRequestor.IsClosed: Boolean;
begin
  Result := TInterlocked.CompareExchange(FClosed, 0, 0) <> 0;
end;

procedure TRaimsRequestor.EnsureOpen;
begin
  if IsClosed then raise ERaimsConnectionError.Create('The Raims client is closed.');
end;

procedure TRaimsRequestor.Close;
begin
  if FLock = nil then Exit;
  TInterlocked.Exchange(FClosed, 1);
  if FCloseEvent <> nil then FCloseEvent.SetEvent;
  TMonitor.Enter(FLock);
  try
    if FTransport <> nil then
    begin
      FTransport.Close;
      FTransport := nil;
    end;
    FApiKey := '';
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRaimsRequestor.Notify(const Method, PathTemplate: string; Attempt: Integer;
  const Started: TStopwatch; const Metadata: TRaimsResponseMetadata);
var
  Diagnostic: TRaimsRequestAttempt;
begin
  if not Assigned(FOptions.RequestObserver) or FNotifying then Exit;
  Diagnostic.Method := Method;
  Diagnostic.PathTemplate := PathTemplate;
  Diagnostic.DurationMilliseconds := Started.ElapsedMilliseconds;
  Diagnostic.Attempt := Attempt;
  Diagnostic.StatusCode := Metadata.StatusCode;
  Diagnostic.RequestId := Metadata.RequestId;
  FNotifying := True;
  try
    try
      FOptions.RequestObserver(Diagnostic);
    except
      on E: EOutOfMemory do raise;
      on E: EExternalException do raise;
      on E: Exception do ;
    end;
  finally
    FNotifying := False;
  end;
end;

function TRaimsRequestor.Interpret(const Response: TRaimsHttpResponse;
  const Metadata: TRaimsResponseMetadata;
  const SuccessStatuses: array of Integer): TRaimsResponse;
var
  Code: Integer;
  Accepted: Boolean;
  ContentType, MessageText: string;
  Data, Error: TJSONObject;
  ErrorValue: TJSONValue;
begin
  Result.Metadata := Metadata;
  try
    Result.Body := RaimsDecodeUtf8(Response.Body);
  except
    on E: ERaimsUnexpectedResponseError do
      raise ERaimsUnexpectedResponseError.Create(E.Message, Metadata);
  end;
  if (Response.StatusCode >= 300) and (Response.StatusCode < 400) then
    raise ERaimsUnexpectedResponseError.Create('The API returned a redirect; redirects are not followed.', Metadata);
  if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
  begin
    Data := nil;
    Error := nil;
    try
      try
        Data := RaimsParseObject(Result.Body);
        ErrorValue := Data.GetValue('error');
        if ErrorValue is TJSONObject then Error := TJSONObject(ErrorValue);
      except
        on E: ERaimsUnexpectedResponseError do ;
      end;
      MessageText := 'The API request failed with HTTP ' + IntToStr(Response.StatusCode) + '.';
      case Response.StatusCode of
        400, 405, 413, 415, 422: raise ERaimsInvalidRequestError.Create(MessageText, Metadata, Error);
        401: raise ERaimsAuthenticationError.Create(MessageText, Metadata, Error);
        403: raise ERaimsPermissionError.Create(MessageText, Metadata, Error);
        404: raise ERaimsNotFoundError.Create(MessageText, Metadata, Error);
        409: raise ERaimsConflictError.Create(MessageText, Metadata, Error);
        429: raise ERaimsRateLimitError.Create(MessageText, Metadata, Error);
      else
        raise ERaimsApiError.Create(MessageText, Metadata, Error);
      end;
    finally
      Data.Free;
    end;
  end;
  Accepted := False;
  for Code in SuccessStatuses do
    if Code = Response.StatusCode then Accepted := True;
  if not Accepted then
    raise ERaimsUnexpectedResponseError.Create('The API returned an undocumented success status.', Metadata);
  if Response.StatusCode = 204 then
  begin
    if Trim(Result.Body) <> '' then
      raise ERaimsUnexpectedResponseError.Create('The API returned a body for an empty response.', Metadata);
    Result.Body := '';
    Exit;
  end;
  try
    ContentType := RaimsHeaderValue(Response.Headers, 'Content-Type');
  except
    on E: ERaimsUnexpectedResponseError do
      raise ERaimsUnexpectedResponseError.Create(E.Message, Metadata);
  end;
  if (ContentType <> '') and not TRegEx.IsMatch(ContentType,
    '\Aapplication/(?:[a-z0-9.+-]+\+)?json(?:\s*;.*)?\z', [roIgnoreCase]) then
    raise ERaimsUnexpectedResponseError.Create('The API returned a non-JSON success response.', Metadata);
  try
    Data := RaimsParseObject(Result.Body);
    Data.Free;
  except
    on E: ERaimsUnexpectedResponseError do
      raise ERaimsUnexpectedResponseError.Create(E.Message, Metadata);
  end;
end;

function TRaimsRequestor.Request(const Method, PathTemplate, Path: string;
  Query, Body: TRaimsParams; const Options: TRaimsRequestOptions;
  const SuccessStatuses: array of Integer): TRaimsResponse;
var
  Wire: TRaimsHttpRequest;
  Response: TRaimsHttpResponse;
  Metadata: TRaimsResponseMetadata;
  Key, QueryString: string;
  Timeout, Retries, Attempt, Delay: Integer;
  Started: TStopwatch;
  FailedConnection: Boolean;
begin
  EnsureOpen;
  if (Copy(Path, 1, 4) <> '/v1/') or (Pos('?', Path) > 0) or
    (Pos('#', Path) > 0) or (Pos('\', Path) > 0) or (Pos('://', Path) > 0) then
    raise EArgumentException.Create('Requests must use a public API resource path.');
  if (Copy(PathTemplate, 1, 4) <> '/v1/') or (Pos('?', PathTemplate) > 0) or
    (Pos('#', PathTemplate) > 0) then
    raise EArgumentException.Create('Diagnostics require a parameterized public resource path.');
  if (Method <> 'GET') and (Method <> 'HEAD') and (Method <> 'POST') and
    (Method <> 'PATCH') and (Method <> 'PUT') and (Method <> 'DELETE') then
    raise EArgumentException.Create('The HTTP method is not supported.');
  ValidateHeaderInput(Options.ApiKey, 'API key', True);
  ValidateHeaderInput(Options.IdempotencyKey, 'Idempotency key', True);
  if Length(Options.IdempotencyKey) > 255 then
    raise EArgumentOutOfRangeException.Create('The idempotency key is too long.');
  Timeout := Options.TimeoutMilliseconds;
  if Timeout = 0 then Timeout := FOptions.TimeoutMilliseconds;
  if (Timeout < 1) or (Timeout > 300000) then
    raise EArgumentOutOfRangeException.Create('TimeoutMilliseconds must be between 1 and 300000.');
  Retries := Options.MaxNetworkRetries;
  if Retries = -1 then Retries := FOptions.MaxNetworkRetries;
  if (Retries < 0) or (Retries > 5) then
    raise EArgumentOutOfRangeException.Create('MaxNetworkRetries must be between 0 and 5.');
  if (Method <> 'GET') and (Method <> 'HEAD') then Retries := 0;
  QueryString := BuildQuery(Query);
  Wire.Method := Method;
  Wire.PathTemplate := PathTemplate;
  Wire.Url := FOptions.ApiBase + Path;
  if QueryString <> '' then Wire.Url := Wire.Url + '?' + QueryString;
  Wire.Body := '';
  if Body <> nil then Wire.Body := Body.ToJson;
  if ((Method = 'GET') or (Method = 'HEAD')) and (Body <> nil) then
    raise EArgumentException.Create('Read requests do not accept a JSON body.');
  Wire.TimeoutMilliseconds := Timeout;
  Wire.MaxResponseBytes := FOptions.MaxResponseBytes;
  TMonitor.Enter(FLock);
  try
    EnsureOpen;
    Key := Options.ApiKey;
    if Key = '' then Key := FApiKey;
    SetLength(Wire.Headers, 4);
    Wire.Headers[0] := TRaimsHeader.Create('Authorization', 'Bearer ' + Key);
    Wire.Headers[1] := TRaimsHeader.Create('Accept', 'application/json');
    Wire.Headers[2] := TRaimsHeader.Create('Accept-Encoding', 'identity');
    Wire.Headers[3] := TRaimsHeader.Create('User-Agent', 'RaimsDelphi/' + RaimsSdkVersion);
    if Body <> nil then
    begin
      SetLength(Wire.Headers, Length(Wire.Headers) + 1);
      Wire.Headers[High(Wire.Headers)] := TRaimsHeader.Create('Content-Type', 'application/json');
    end;
    if Options.IdempotencyKey <> '' then
    begin
      SetLength(Wire.Headers, Length(Wire.Headers) + 1);
      Wire.Headers[High(Wire.Headers)] := TRaimsHeader.Create('Idempotency-Key', Options.IdempotencyKey);
    end;
    for Attempt := 1 to Retries + 1 do
    begin
      EnsureOpen;
      Metadata.StatusCode := 0;
      Metadata.RequestId := '';
      Metadata.RetryAfter := '';
      Metadata.AttemptCount := Attempt;
      Started := TStopwatch.StartNew;
      FailedConnection := False;
      try
        try
          Response := FTransport.Send(Wire);
          Metadata.StatusCode := Response.StatusCode;
          Metadata.RequestId := RaimsHeaderValue(Response.Headers, 'Request-Id');
          if Metadata.RequestId = '' then
            Metadata.RequestId := RaimsHeaderValue(Response.Headers, 'X-Request-Id');
          Metadata.RetryAfter := RaimsHeaderValue(Response.Headers, 'Retry-After');
          if Length(Response.Body) > FOptions.MaxResponseBytes then
            raise ERaimsUnexpectedResponseError.Create('The API response exceeds the supported size.', Metadata);
        except
          on E: EOutOfMemory do raise;
          on E: EExternalException do raise;
          on E: ERaimsUnexpectedResponseError do
          begin
            MergeResponseMetadata(E.LastResponse, Metadata);
            raise ERaimsUnexpectedResponseError.Create(E.Message, Metadata);
          end;
          on E: ERaimsConnectionError do
          begin
            MergeResponseMetadata(E.LastResponse, Metadata);
            FailedConnection := True;
          end;
          on E: ENetException do FailedConnection := True;
        end;
      finally
        Notify(Method, PathTemplate, Attempt, Started, Metadata);
      end;
      if IsClosed then
        raise ERaimsConnectionError.Create('The API request was cancelled by client closure.', Metadata);
      Delay := -1;
      if (Attempt <= Retries) and (FailedConnection or CanRetryStatus(Metadata.StatusCode)) then
        Delay := RetryDelay(Attempt, Metadata.RetryAfter);
      if Delay >= 0 then
      begin
        if FCloseEvent.WaitFor(Delay) = wrSignaled then
          raise ERaimsConnectionError.Create('The API request was cancelled by client closure.', Metadata);
        Continue;
      end;
      if FailedConnection then
        raise ERaimsConnectionError.Create('The API connection failed or timed out.', Metadata);
      Exit(Interpret(Response, Metadata, SuccessStatuses));
    end;
    raise ERaimsConnectionError.Create('The API request could not be completed.');
  finally
    Key := '';
    Wire.Headers := nil;
    TMonitor.Exit(FLock);
  end;
end;

end.
