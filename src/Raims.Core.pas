unit Raims.Core;

{$ZEROBASEDSTRINGS OFF}

{$IF CompilerVersion < 34.0}
  {$MESSAGE FATAL 'Raims requires Delphi 10.4 or newer.'}
{$IFEND}

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections;

type
  TRaimsHeader = record
    Name: string;
    Value: string;
    class function Create(const AName, AValue: string): TRaimsHeader; static;
  end;

  TRaimsResponseMetadata = record
    StatusCode: Integer;
    RequestId: string;
    RetryAfter: string;
    AttemptCount: Integer;
  end;

  TRaimsResponse = record
    Body: string;
    Metadata: TRaimsResponseMetadata;
  end;

  TRaimsRequestAttempt = record
    Method: string;
    PathTemplate: string;
    DurationMilliseconds: Int64;
    Attempt: Integer;
    StatusCode: Integer;
    RequestId: string;
  end;

  TRaimsRequestObserver = reference to procedure(const Attempt: TRaimsRequestAttempt);

  TRaimsRequestOptions = record
    ApiKey: string;
    IdempotencyKey: string;
    TimeoutMilliseconds: Integer;
    MaxNetworkRetries: Integer;
    class function Default: TRaimsRequestOptions; static;
  end;

  TRaimsClientOptions = record
    ApiBase: string;
    TimeoutMilliseconds: Integer;
    MaxNetworkRetries: Integer;
    MaxResponseBytes: Integer;
    RequestObserver: TRaimsRequestObserver;
    class function Default: TRaimsClientOptions; static;
  end;

  TRaimsHttpRequest = record
    Method: string;
    PathTemplate: string;
    Url: string;
    Body: string;
    Headers: TArray<TRaimsHeader>;
    TimeoutMilliseconds: Integer;
    MaxResponseBytes: Integer;
  end;

  TRaimsHttpResponse = record
    StatusCode: Integer;
    Headers: TArray<TRaimsHeader>;
    Body: TBytes;
  end;

  IRaimsTransport = interface
    ['{F04B5327-15BB-42AF-83DF-A52D9D9F0904}']
    function Send(const Request: TRaimsHttpRequest): TRaimsHttpResponse;
    procedure Close;
  end;

  ERaimsException = class(Exception)
  private
    FLastResponse: TRaimsResponseMetadata;
  public
    constructor Create(const Message: string); overload;
    constructor Create(const Message: string; const Metadata: TRaimsResponseMetadata); overload;
    property LastResponse: TRaimsResponseMetadata read FLastResponse;
  end;

  ERaimsApiError = class(ERaimsException)
  private
    FError: TJSONObject;
    function ErrorText(const Name: string): string;
    function GetCode: string;
    function GetApiMessage: string;
    function GetDetails: TJSONArray;
    function GetApiError: TJSONObject;
  public
    constructor Create(const Message: string; const Metadata: TRaimsResponseMetadata;
      const Error: TJSONObject); reintroduce;
    destructor Destroy; override;
    property Code: string read GetCode;
    property ApiMessage: string read GetApiMessage;
    property Details: TJSONArray read GetDetails;
    property ApiError: TJSONObject read GetApiError;
  end;

  ERaimsInvalidRequestError = class(ERaimsApiError);
  ERaimsAuthenticationError = class(ERaimsApiError);
  ERaimsPermissionError = class(ERaimsApiError);
  ERaimsNotFoundError = class(ERaimsApiError);
  ERaimsConflictError = class(ERaimsApiError);
  ERaimsRateLimitError = class(ERaimsApiError);
  ERaimsConnectionError = class(ERaimsException);
  ERaimsUnexpectedResponseError = class(ERaimsException);
  ERaimsSignatureError = class(ERaimsException);

  TRaimsObject = class
  private
    FData: TJSONObject;
  protected
    procedure SetValue(const Name: string; Value: TJSONValue);
    function Field(const Name: string): TJSONValue;
  public
    constructor Create; overload;
    constructor Create(const Json: string); overload;
    constructor Create(const Data: TJSONObject); overload;
    destructor Destroy; override;
    function HasField(const Name: string): Boolean;
    function IsNull(const Name: string): Boolean;
    function GetString(const Name: string): string;
    function GetInt64(const Name: string): Int64;
    function GetDouble(const Name: string): Double;
    function GetBoolean(const Name: string): Boolean;
    function GetObject(const Name: string): TJSONObject;
    function GetArray(const Name: string): TJSONArray;
    function RawJson: TJSONObject;
    function ToJson: string;
    function ToString: string; override;
  end;

  TRaimsParams = class(TRaimsObject)
  public
    procedure SetString(const Name, Value: string);
    procedure SetInt64(const Name: string; Value: Int64);
    procedure SetBoolean(const Name: string; Value: Boolean);
    procedure SetJson(const Name: string; const Value: TJSONValue);
    procedure SetNull(const Name: string);
    procedure Unset(const Name: string);
  end;

  TRaimsResource = class(TRaimsObject)
  private
    FLastResponse: TRaimsResponseMetadata;
  public
    constructor Create(const Response: TRaimsResponse); reintroduce; overload; virtual;
    property LastResponse: TRaimsResponseMetadata read FLastResponse;
  end;

  IRaimsRequestor = interface
    ['{C424EE84-7EAF-4EDC-BF99-F710C3A512DF}']
    function Request(const Method, PathTemplate, Path: string;
      Query, Body: TRaimsParams; const Options: TRaimsRequestOptions;
      const SuccessStatuses: array of Integer): TRaimsResponse;
    procedure Close;
    function IsClosed: Boolean;
  end;

  TRaimsService = class
  protected
    FRequestor: IRaimsRequestor;
  public
    constructor Create(const Requestor: IRaimsRequestor);
  end;

  TRaimsCollection = class;
  TRaimsPageLoader = reference to function(const Cursor: string;
    Previous: Boolean): TRaimsCollection;
  TRaimsCollection = class(TRaimsResource)
  private
    FLoader: TRaimsPageLoader;
    FInitialAfter: string;
    FInitialBefore: string;
    function Navigate(Previous: Boolean): TRaimsCollection;
    function Cursor(Previous: Boolean): string;
  public
    procedure AttachPageLoader(const Loader: TRaimsPageLoader;
      const InitialAfter, InitialBefore: string);
    function GetPage: TJSONObject;
    function NextPage: TRaimsCollection;
    function PreviousPage: TRaimsCollection;
    function AutoPagingEach(const Callback: TProc<TJSONObject>;
      Limit: Integer = 1000000): Integer;
  end;

function RaimsEncodePathSegment(const Value: string): string;
function RaimsEncodeUtf8(const Value: string): TBytes;
function RaimsDecodeUtf8(const Value: TBytes): string;
function RaimsParseObject(const Json: string): TJSONObject;
function RaimsIsJsonString(const Value: TJSONValue): Boolean;
function RaimsHeaderValue(const Headers: TArray<TRaimsHeader>; const Name: string): string;

implementation

uses
  System.Math;

function RaimsIsJsonString(const Value: TJSONValue): Boolean;
begin
  Result := (Value is TJSONString) and not (Value is TJSONNumber);
end;

procedure CheckJsonEnvelope(const Json: string);
var
  I, Depth: Integer;
  InString, Escaped, Finished, Started: Boolean;
  C: Char;
begin
  Depth := 0;
  InString := False;
  Escaped := False;
  Finished := False;
  Started := False;
  for I := 1 to Length(Json) do
  begin
    C := Json[I];
    if InString then
    begin
      if Ord(C) < 32 then
        raise ERaimsUnexpectedResponseError.Create('The response contains invalid JSON.');
      if Escaped then Escaped := False
      else if C = '\' then Escaped := True
      else if C = '"' then InString := False;
      Continue;
    end;
    if CharInSet(C, [#9, #10, #13, ' ']) then Continue;
    if Finished then
      raise ERaimsUnexpectedResponseError.Create('The response contains trailing data after JSON.');
    if not Started then
    begin
      if C <> '{' then
        raise ERaimsUnexpectedResponseError.Create('The response must be a valid JSON object.');
      Started := True;
    end;
    if C = '"' then InString := True
    else if (C = '{') or (C = '[') then
    begin
      Inc(Depth);
      if Depth > 128 then
        raise ERaimsUnexpectedResponseError.Create('JSON nesting exceeds the supported depth.');
    end
    else if (C = '}') or (C = ']') then
    begin
      Dec(Depth);
      if Depth < 0 then
        raise ERaimsUnexpectedResponseError.Create('The response contains invalid JSON.');
      Finished := Depth = 0;
    end;
  end;
  if not Finished or InString then
    raise ERaimsUnexpectedResponseError.Create('The response must be a valid JSON object.');
end;

procedure CheckObjectTree(const Value: TJSONValue; Depth: Integer);
var
  Names: TDictionary<string, Boolean>;
  Pair: TJSONPair;
  Item: TJSONValue;
begin
  if Depth > 128 then
    raise ERaimsUnexpectedResponseError.Create('JSON nesting exceeds the supported depth.');
  if Value is TJSONObject then
  begin
    Names := TDictionary<string, Boolean>.Create;
    try
      for Pair in TJSONObject(Value) do
      begin
        if Names.ContainsKey(Pair.JsonString.Value) then
          raise ERaimsUnexpectedResponseError.Create('JSON contains duplicate field names.');
        Names.Add(Pair.JsonString.Value, True);
        CheckObjectTree(Pair.JsonValue, Depth + 1);
      end;
    finally
      Names.Free;
    end;
  end
  else if Value is TJSONArray then
    for Item in TJSONArray(Value) do
      CheckObjectTree(Item, Depth + 1);
end;

function RaimsParseObject(const Json: string): TJSONObject;
var
  Parsed: TJSONValue;
begin
  CheckJsonEnvelope(Json);
  Parsed := TJSONObject.ParseJSONValue(Json, False, False);
  if not (Parsed is TJSONObject) then
  begin
    Parsed.Free;
    raise ERaimsUnexpectedResponseError.Create('The response must be a valid JSON object.');
  end;
  try
    CheckObjectTree(Parsed, 0);
    Result := TJSONObject(Parsed);
  except
    Parsed.Free;
    raise;
  end;
end;

function ReadUtf8CodePoint(const Value: TBytes; var Index: Integer;
  ByteCount: Integer): Cardinal;
var
  First, Continuation: Byte;
  Width, Offset: Integer;
  Minimum: Cardinal;
begin
  First := Value[Index];
  if First <= $7F then
  begin
    Result := First;
    Inc(Index);
    Exit;
  end;
  if (First >= $C2) and (First <= $DF) then
  begin
    Width := 2;
    Result := First and $1F;
    Minimum := $80;
  end
  else if (First >= $E0) and (First <= $EF) then
  begin
    Width := 3;
    Result := First and $0F;
    Minimum := $800;
  end
  else if (First >= $F0) and (First <= $F4) then
  begin
    Width := 4;
    Result := First and $07;
    Minimum := $10000;
  end
  else
    raise ERaimsUnexpectedResponseError.Create('The response contains invalid UTF-8.');
  if ByteCount - Index < Width then
    raise ERaimsUnexpectedResponseError.Create('The response contains invalid UTF-8.');
  for Offset := 1 to Width - 1 do
  begin
    Continuation := Value[Index + Offset];
    if (Continuation < $80) or (Continuation > $BF) then
      raise ERaimsUnexpectedResponseError.Create('The response contains invalid UTF-8.');
    Result := (Result shl 6) or (Continuation and $3F);
  end;
  if (Result < Minimum) or (Result > $10FFFF) or
    ((Result >= $D800) and (Result <= $DFFF)) then
    raise ERaimsUnexpectedResponseError.Create('The response contains invalid UTF-8.');
  Inc(Index, Width);
end;

function ReadUtf16CodePoint(const Value: string; var Index: Integer;
  CharacterCount: Integer): Cardinal;
var
  First, Second: Cardinal;
begin
  First := Ord(Value[Index + 1]);
  if (First >= $D800) and (First <= $DBFF) then
  begin
    if CharacterCount - Index < 2 then
      raise EArgumentException.Create('Request text contains invalid Unicode.');
    Second := Ord(Value[Index + 2]);
    if (Second < $DC00) or (Second > $DFFF) then
      raise EArgumentException.Create('Request text contains invalid Unicode.');
    Result := $10000 + ((First - $D800) shl 10) + (Second - $DC00);
    Inc(Index, 2);
  end
  else
  begin
    if (First >= $DC00) and (First <= $DFFF) then
      raise EArgumentException.Create('Request text contains invalid Unicode.');
    Result := First;
    Inc(Index);
  end;
end;

function RaimsDecodeUtf8(const Value: TBytes): string;
var
  ByteCount, CharacterCount, InputIndex, OutputIndex: Integer;
  CodePoint: Cardinal;
begin
  Result := '';
  if Length(Value) = 0 then Exit;
  if Length(Value) > MaxInt then
    raise ERaimsUnexpectedResponseError.Create('The UTF-8 input exceeds the supported size.');
  ByteCount := Integer(Length(Value));
  CharacterCount := 0;
  InputIndex := 0;
  while InputIndex < ByteCount do
  begin
    CodePoint := ReadUtf8CodePoint(Value, InputIndex, ByteCount);
    if CodePoint > $FFFF then Inc(CharacterCount, 2)
    else Inc(CharacterCount);
  end;
  SetLength(Result, CharacterCount);
  InputIndex := 0;
  OutputIndex := 0;
  while InputIndex < ByteCount do
  begin
    CodePoint := ReadUtf8CodePoint(Value, InputIndex, ByteCount);
    if CodePoint > $FFFF then
    begin
      Dec(CodePoint, $10000);
      Result[OutputIndex + 1] := Char($D800 or (CodePoint shr 10));
      Result[OutputIndex + 2] := Char($DC00 or (CodePoint and $3FF));
      Inc(OutputIndex, 2);
    end
    else
    begin
      Result[OutputIndex + 1] := Char(CodePoint);
      Inc(OutputIndex);
    end;
  end;
end;

function RaimsEncodeUtf8(const Value: string): TBytes;
var
  ByteCount, CharacterCount, InputIndex, OutputIndex, Width: Integer;
  CodePoint: Cardinal;
begin
  Result := nil;
  if Length(Value) = 0 then Exit;
  if Length(Value) > MaxInt then
    raise EArgumentException.Create('Request text exceeds the supported size.');
  CharacterCount := Integer(Length(Value));
  ByteCount := 0;
  InputIndex := 0;
  while InputIndex < CharacterCount do
  begin
    CodePoint := ReadUtf16CodePoint(Value, InputIndex, CharacterCount);
    if CodePoint <= $7F then Width := 1
    else if CodePoint <= $7FF then Width := 2
    else if CodePoint <= $FFFF then Width := 3
    else Width := 4;
    if ByteCount > MaxInt - Width then
      raise EArgumentException.Create('Request text exceeds the supported size.');
    Inc(ByteCount, Width);
  end;
  SetLength(Result, ByteCount);
  InputIndex := 0;
  OutputIndex := 0;
  while InputIndex < CharacterCount do
  begin
    CodePoint := ReadUtf16CodePoint(Value, InputIndex, CharacterCount);
    if CodePoint <= $7F then
    begin
      Result[OutputIndex] := Byte(CodePoint);
      Inc(OutputIndex);
    end
    else if CodePoint <= $7FF then
    begin
      Result[OutputIndex] := Byte($C0 or (CodePoint shr 6));
      Result[OutputIndex + 1] := Byte($80 or (CodePoint and $3F));
      Inc(OutputIndex, 2);
    end
    else if CodePoint <= $FFFF then
    begin
      Result[OutputIndex] := Byte($E0 or (CodePoint shr 12));
      Result[OutputIndex + 1] := Byte($80 or ((CodePoint shr 6) and $3F));
      Result[OutputIndex + 2] := Byte($80 or (CodePoint and $3F));
      Inc(OutputIndex, 3);
    end
    else
    begin
      Result[OutputIndex] := Byte($F0 or (CodePoint shr 18));
      Result[OutputIndex + 1] := Byte($80 or ((CodePoint shr 12) and $3F));
      Result[OutputIndex + 2] := Byte($80 or ((CodePoint shr 6) and $3F));
      Result[OutputIndex + 3] := Byte($80 or (CodePoint and $3F));
      Inc(OutputIndex, 4);
    end;
  end;
end;

function RaimsEncodePathSegment(const Value: string): string;
const
  Hex: string = '0123456789ABCDEF';
var
  Bytes: TBytes;
  B: Byte;
  C: Char;
begin
  if (Value = '') or (Value = '.') or (Value = '..') then
    raise EArgumentException.Create('Path arguments must be non-empty resource identifiers.');
  for C in Value do
    if Ord(C) <= 32 then
      raise EArgumentException.Create('Path arguments must not contain whitespace or control characters.');
  Bytes := RaimsEncodeUtf8(Value);
  Result := '';
  for B in Bytes do
    if ((B >= Ord('a')) and (B <= Ord('z'))) or
       ((B >= Ord('A')) and (B <= Ord('Z'))) or
       ((B >= Ord('0')) and (B <= Ord('9'))) or
       (B = Ord('-')) or (B = Ord('_')) or (B = Ord('.')) or (B = Ord('~')) then
      Result := Result + Char(B)
    else
      Result := Result + '%' + Hex[(B shr 4) + 1] + Hex[(B and 15) + 1];
end;

function RaimsHeaderValue(const Headers: TArray<TRaimsHeader>; const Name: string): string;
var
  Header: TRaimsHeader;
  Found: Boolean;
begin
  Result := '';
  Found := False;
  for Header in Headers do
    if SameText(Header.Name, Name) then
    begin
      if Found then
        raise ERaimsUnexpectedResponseError.Create('A response header occurs more than once.');
      Found := True;
      Result := Header.Value;
    end;
end;

class function TRaimsHeader.Create(const AName, AValue: string): TRaimsHeader;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;

class function TRaimsRequestOptions.Default: TRaimsRequestOptions;
begin
  Result.ApiKey := '';
  Result.IdempotencyKey := '';
  Result.TimeoutMilliseconds := 0;
  Result.MaxNetworkRetries := -1;
end;

class function TRaimsClientOptions.Default: TRaimsClientOptions;
begin
  Result.ApiBase := 'https://api.raims.com';
  Result.TimeoutMilliseconds := 80000;
  Result.MaxNetworkRetries := 0;
  Result.MaxResponseBytes := 16 * 1024 * 1024;
  Result.RequestObserver := nil;
end;

constructor ERaimsException.Create(const Message: string);
begin
  inherited Create(Message);
  FLastResponse.StatusCode := 0;
  FLastResponse.RequestId := '';
  FLastResponse.RetryAfter := '';
  FLastResponse.AttemptCount := 0;
end;

constructor ERaimsException.Create(const Message: string; const Metadata: TRaimsResponseMetadata);
begin
  inherited Create(Message);
  FLastResponse := Metadata;
end;

constructor ERaimsApiError.Create(const Message: string; const Metadata: TRaimsResponseMetadata;
  const Error: TJSONObject);
begin
  inherited Create(Message, Metadata);
  if Error <> nil then
    FError := Error.Clone as TJSONObject;
end;

destructor ERaimsApiError.Destroy;
begin
  FError.Free;
  inherited;
end;

function ERaimsApiError.ErrorText(const Name: string): string;
var
  V: TJSONValue;
begin
  Result := '';
  if FError = nil then Exit;
  V := FError.GetValue(Name);
  if RaimsIsJsonString(V) then Result := V.Value;
end;

function ERaimsApiError.GetCode: string;
begin
  Result := ErrorText('code');
end;

function ERaimsApiError.GetApiMessage: string;
begin
  Result := ErrorText('message');
end;

function ERaimsApiError.GetDetails: TJSONArray;
var
  Value: TJSONValue;
begin
  Result := nil;
  if FError = nil then Exit;
  Value := FError.GetValue('details');
  if Value is TJSONArray then Result := Value.Clone as TJSONArray;
end;

function ERaimsApiError.GetApiError: TJSONObject;
begin
  Result := nil;
  if FError <> nil then Result := FError.Clone as TJSONObject;
end;

constructor TRaimsObject.Create;
begin
  inherited Create;
  FData := TJSONObject.Create;
end;

constructor TRaimsObject.Create(const Json: string);
begin
  inherited Create;
  FData := RaimsParseObject(Json);
end;

constructor TRaimsObject.Create(const Data: TJSONObject);
begin
  inherited Create;
  if Data = nil then FData := TJSONObject.Create
  else FData := Data.Clone as TJSONObject;
end;

destructor TRaimsObject.Destroy;
begin
  FData.Free;
  inherited;
end;

function TRaimsObject.Field(const Name: string): TJSONValue;
var
  Pair: TJSONPair;
begin
  Result := nil;
  for Pair in FData do
    if Pair.JsonString.Value = Name then Exit(Pair.JsonValue);
end;

function TRaimsObject.HasField(const Name: string): Boolean;
begin
  Result := Field(Name) <> nil;
end;

function TRaimsObject.IsNull(const Name: string): Boolean;
begin
  Result := Field(Name) is TJSONNull;
end;

function TRaimsObject.GetString(const Name: string): string;
var
  V: TJSONValue;
begin
  V := Field(Name);
  if (V = nil) or (V is TJSONNull) then Exit('');
  if not RaimsIsJsonString(V) then
    raise ERaimsUnexpectedResponseError.Create('A response field has an incompatible type.');
  Result := V.Value;
end;

function TRaimsObject.GetInt64(const Name: string): Int64;
var
  V: TJSONValue;
begin
  V := Field(Name);
  if (V = nil) or (V is TJSONNull) then Exit(0);
  if not (V is TJSONNumber) then
    raise ERaimsUnexpectedResponseError.Create('A response integer is invalid or outside the 64-bit range.');
  if not TryStrToInt64(V.Value, Result) then
    raise ERaimsUnexpectedResponseError.Create('A response integer is invalid or outside the 64-bit range.');
end;

function TRaimsObject.GetBoolean(const Name: string): Boolean;
var
  V: TJSONValue;
begin
  V := Field(Name);
  if (V = nil) or (V is TJSONNull) then Exit(False);
  if V is TJSONTrue then Exit(True);
  if V is TJSONFalse then Exit(False);
  if V is TJSONBool then Exit(TJSONBool(V).AsBoolean);
  raise ERaimsUnexpectedResponseError.Create('A response field has an incompatible type.');
end;

function TRaimsObject.GetDouble(const Name: string): Double;
var
  V: TJSONValue;
  Settings: TFormatSettings;
begin
  V := Field(Name);
  if (V = nil) or (V is TJSONNull) then Exit(0);
  Settings := TFormatSettings.Create;
  Settings.DecimalSeparator := '.';
  Settings.ThousandSeparator := #0;
  if not (V is TJSONNumber) then
    raise ERaimsUnexpectedResponseError.Create('A response number has an incompatible type.');
  if not TryStrToFloat(V.Value, Result, Settings) then
    raise ERaimsUnexpectedResponseError.Create('A response number has an incompatible type.');
  if IsNan(Result) or IsInfinite(Result) then
    raise ERaimsUnexpectedResponseError.Create('A response number has an incompatible type.');
end;

function TRaimsObject.GetObject(const Name: string): TJSONObject;
var
  V: TJSONValue;
begin
  V := Field(Name);
  if (V = nil) or (V is TJSONNull) then Exit(nil);
  if not (V is TJSONObject) then
    raise ERaimsUnexpectedResponseError.Create('A response field has an incompatible type.');
  Result := TJSONObject(V);
end;

function TRaimsObject.GetArray(const Name: string): TJSONArray;
var
  V: TJSONValue;
begin
  V := Field(Name);
  if (V = nil) or (V is TJSONNull) then Exit(nil);
  if not (V is TJSONArray) then
    raise ERaimsUnexpectedResponseError.Create('A response field has an incompatible type.');
  Result := TJSONArray(V);
end;

function TRaimsObject.RawJson: TJSONObject;
begin
  Result := FData.Clone as TJSONObject;
end;

function TRaimsObject.ToJson: string;
begin
  Result := FData.ToJSON;
end;

function TRaimsObject.ToString: string;
begin
  Result := ClassName;
end;

procedure TRaimsObject.SetValue(const Name: string; Value: TJSONValue);
var
  Previous: TJSONPair;
begin
  Previous := FData.RemovePair(Name);
  Previous.Free;
  FData.AddPair(Name, Value);
end;

procedure TRaimsParams.SetString(const Name, Value: string);
begin
  SetValue(Name, TJSONString.Create(Value));
end;

procedure TRaimsParams.SetInt64(const Name: string; Value: Int64);
begin
  SetValue(Name, TJSONNumber.Create(IntToStr(Value)));
end;

procedure TRaimsParams.SetBoolean(const Name: string; Value: Boolean);
begin
  SetValue(Name, TJSONBool.Create(Value));
end;

procedure TRaimsParams.SetJson(const Name: string; const Value: TJSONValue);
begin
  if Value = nil then SetNull(Name)
  else SetValue(Name, Value.Clone as TJSONValue);
end;

procedure TRaimsParams.SetNull(const Name: string);
begin
  SetValue(Name, TJSONNull.Create);
end;

procedure TRaimsParams.Unset(const Name: string);
var
  Previous: TJSONPair;
begin
  Previous := FData.RemovePair(Name);
  Previous.Free;
end;

constructor TRaimsResource.Create(const Response: TRaimsResponse);
begin
  if Response.Body = '' then inherited Create
  else inherited Create(Response.Body);
  FLastResponse := Response.Metadata;
end;

constructor TRaimsService.Create(const Requestor: IRaimsRequestor);
begin
  inherited Create;
  if Requestor = nil then raise EArgumentNilException.Create('Requestor');
  FRequestor := Requestor;
end;

procedure TRaimsCollection.AttachPageLoader(const Loader: TRaimsPageLoader;
  const InitialAfter, InitialBefore: string);
begin
  if Assigned(FLoader) then
    raise EInvalidOpException.Create('The page loader is already attached.');
  if not Assigned(Loader) then raise EArgumentNilException.Create('Loader');
  FLoader := Loader;
  FInitialAfter := InitialAfter;
  FInitialBefore := InitialBefore;
end;

function TRaimsCollection.GetPage: TJSONObject;
begin
  Result := GetObject('page');
end;

function TRaimsCollection.Cursor(Previous: Boolean): string;
var
  P: TJSONObject;
  V: TJSONValue;
  Name: string;
begin
  P := GetPage;
  if Previous then Name := 'previous_before' else Name := 'next_after';
  V := nil;
  if P <> nil then V := P.GetValue(Name);
  if not RaimsIsJsonString(V) then
    raise ERaimsUnexpectedResponseError.Create('Pagination returned a missing or repeated cursor.', LastResponse);
  if V.Value = '' then
    raise ERaimsUnexpectedResponseError.Create('Pagination returned a missing or repeated cursor.', LastResponse);
  Result := V.Value;
end;

function TRaimsCollection.Navigate(Previous: Boolean): TRaimsCollection;
var
  Page: TJSONObject;
  V: TJSONValue;
  Name, NextCursor, Initial: string;
begin
  Result := nil;
  Page := GetPage;
  if Page = nil then Exit;
  if Previous then Name := 'has_previous' else Name := 'has_next';
  V := Page.GetValue(Name);
  if V = nil then Exit;
  if not ((V is TJSONTrue) or (V is TJSONFalse) or (V is TJSONBool)) then
    raise ERaimsUnexpectedResponseError.Create('Pagination returned an invalid page indicator.', LastResponse);
  if SameText(V.Value, 'false') then Exit;
  NextCursor := Cursor(Previous);
  if Previous then Initial := FInitialBefore else Initial := FInitialAfter;
  if NextCursor = Initial then
    raise ERaimsUnexpectedResponseError.Create('Pagination returned a missing or repeated cursor.', LastResponse);
  if not Assigned(FLoader) then
    raise EInvalidOpException.Create('This page is not associated with a request.');
  Result := FLoader(NextCursor, Previous);
  if Result <> nil then
  begin
    try
      if not Assigned(Result.FLoader) then
        if Previous then Result.AttachPageLoader(FLoader, '', NextCursor)
        else Result.AttachPageLoader(FLoader, NextCursor, '');
    except
      Result.Free;
      raise;
    end;
  end;
end;

function TRaimsCollection.NextPage: TRaimsCollection;
begin
  Result := Navigate(False);
end;

function TRaimsCollection.PreviousPage: TRaimsCollection;
begin
  Result := Navigate(True);
end;

function TRaimsCollection.AutoPagingEach(const Callback: TProc<TJSONObject>;
  Limit: Integer): Integer;
var
  Current, Next: TRaimsCollection;
  Seen: TDictionary<string, Boolean>;
  Items: TJSONArray;
  PageInfo: TJSONObject;
  HasNext: TJSONValue;
  Item: TJSONValue;
  NextCursor: string;
begin
  if not Assigned(Callback) then raise EArgumentNilException.Create('Callback');
  if (Limit < 1) or (Limit > 1000000) then
    raise EArgumentOutOfRangeException.Create('Limit must be between 1 and 1000000.');
  Result := 0;
  Current := Self;
  Seen := TDictionary<string, Boolean>.Create;
  try
    if FInitialAfter <> '' then Seen.Add(FInitialAfter, True);
    while Current <> nil do
    begin
      Items := Current.GetArray('list');
      if Items <> nil then
        for Item in Items do
        begin
          if not (Item is TJSONObject) then
            raise ERaimsUnexpectedResponseError.Create('Pagination returned an incompatible item.', Current.LastResponse);
          Callback(TJSONObject(Item));
          Inc(Result);
          if Result >= Limit then Exit;
        end;
      PageInfo := Current.GetPage;
      if PageInfo = nil then Break;
      HasNext := PageInfo.GetValue('has_next');
      if HasNext = nil then Break;
      if SameText(HasNext.Value, 'false') then Break;
      NextCursor := Current.Cursor(False);
      if Seen.ContainsKey(NextCursor) then
        raise ERaimsUnexpectedResponseError.Create('Pagination returned a missing or repeated cursor.', Current.LastResponse);
      Next := Current.NextPage;
      if Next = nil then Break;
      try
        Seen.Add(NextCursor, True);
      except
        Next.Free;
        raise;
      end;
      if Current <> Self then Current.Free;
      Current := Next;
    end;
  finally
    if Current <> Self then Current.Free;
    Seen.Free;
  end;
end;

end.
