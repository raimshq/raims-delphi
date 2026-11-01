unit Raims.Webhooks;

{$ZEROBASEDSTRINGS OFF}

interface

uses
  System.SysUtils, System.JSON, Raims.Core;

type
  TRaimsWebhook = class sealed
  public
    class procedure VerifySignature(const Payload: TBytes;
      const Headers: TArray<TRaimsHeader>; const Secret: string;
      ToleranceSeconds: Int64 = 300; NowSeconds: Int64 = -1); static;
    class function ConstructEvent(const Payload: TBytes;
      const Headers: TArray<TRaimsHeader>; const Secret: string;
      ToleranceSeconds: Int64 = 300; NowSeconds: Int64 = -1): TJSONObject; static;
  end;

implementation

uses
  System.Hash, System.DateUtils, System.RegularExpressions;

function SigningHeader(const Headers: TArray<TRaimsHeader>; const Name: string): string;
var
  Header: TRaimsHeader;
  Count: Integer;
  C: Char;
begin
  Count := 0;
  Result := '';
  for Header in Headers do
    if SameText(Header.Name, Name) then
    begin
      Inc(Count);
      Result := Header.Value;
    end;
  if (Count <> 1) or (Result = '') or (Length(Result) > 16384) then
    raise ERaimsSignatureError.Create('A webhook signing header is missing, repeated or invalid.');
  for C in Result do
    if (Ord(C) < 9) or ((Ord(C) > 9) and (Ord(C) < 32)) or (Ord(C) = 127) then
      raise ERaimsSignatureError.Create('A webhook signing header is invalid.');
end;

function DecodeSecret(const Secret: string): TBytes;
const
  Alphabet: string = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
var
  Encoded: string;
  C: Char;
  I, Carry, Digit, Value: Integer;
begin
  if Copy(Secret, 1, 6) <> 'whsec_' then
    raise ERaimsSignatureError.Create('The webhook signing secret is invalid.');
  Encoded := Copy(Secret, 7, MaxInt);
  if (Length(Encoded) < 1) or (Length(Encoded) > 43) then
    raise ERaimsSignatureError.Create('The webhook signing secret is invalid.');
  if Length(Encoded) > 1 then
    if Encoded[1] = '0' then
      raise ERaimsSignatureError.Create('The webhook signing secret is invalid.');
  SetLength(Result, 32);
  for C in Encoded do
  begin
    Digit := Pos(C, Alphabet) - 1;
    if Digit < 0 then
      raise ERaimsSignatureError.Create('The webhook signing secret is invalid.');
    Carry := Digit;
    for I := 0 to High(Result) do
    begin
      Value := Result[I] * 62 + Carry;
      Result[I] := Value and 255;
      Carry := Value shr 8;
    end;
    if Carry <> 0 then
      raise ERaimsSignatureError.Create('The webhook signing secret is invalid.');
  end;
end;

function HexDigit(C: Char): Integer;
begin
  if (C >= '0') and (C <= '9') then Exit(Ord(C) - Ord('0'));
  if (C >= 'a') and (C <= 'f') then Exit(Ord(C) - Ord('a') + 10);
  if (C >= 'A') and (C <= 'F') then Exit(Ord(C) - Ord('A') + 10);
  Result := -1;
end;

function ConstantTimeSignatureMatch(const Expected: TBytes; const Candidate: string): Boolean;
var
  I, Difference, HighNibble, LowNibble: Integer;
begin
  Result := False;
  if (Length(Candidate) <> 67) or not SameText(Copy(Candidate, 1, 3), 'v1=') then Exit;
  Difference := 0;
  for I := 0 to 31 do
  begin
    HighNibble := HexDigit(Candidate[4 + I * 2]);
    LowNibble := HexDigit(Candidate[5 + I * 2]);
    if (HighNibble < 0) or (LowNibble < 0) then Exit;
    Difference := Difference or (Expected[I] xor ((HighNibble shl 4) or LowNibble));
  end;
  Result := Difference = 0;
end;

class procedure TRaimsWebhook.VerifySignature(const Payload: TBytes;
  const Headers: TArray<TRaimsHeader>; const Secret: string;
  ToleranceSeconds, NowSeconds: Int64);
var
  Id, Timestamp, Signature, Candidate: string;
  Time, Difference: Int64;
  Prefix, SignedData, Key, Expected: TBytes;
  Parts: TArray<string>;
  Matched: Boolean;
begin
  if (ToleranceSeconds < 0) or (NowSeconds < -1) then
    raise EArgumentOutOfRangeException.Create('Webhook tolerance and clock must be non-negative.');
  if NowSeconds = -1 then
    NowSeconds := DateTimeToUnix(TTimeZone.Local.ToUniversalTime(Now), True);
  Id := SigningHeader(Headers, 'webhook-id');
  Timestamp := SigningHeader(Headers, 'webhook-timestamp');
  Signature := SigningHeader(Headers, 'webhook-signature');
  if not TRegEx.IsMatch(Id,
    '\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z', [roIgnoreCase]) then
    raise ERaimsSignatureError.Create('The webhook delivery ID is invalid.');
  if not TRegEx.IsMatch(Timestamp, '\A[0-9]{1,12}\z') or not TryStrToInt64(Timestamp, Time) then
    raise ERaimsSignatureError.Create('The webhook timestamp is invalid or outside the allowed tolerance.');
  if Time > NowSeconds then Difference := Time - NowSeconds else Difference := NowSeconds - Time;
  if Difference > ToleranceSeconds then
    raise ERaimsSignatureError.Create('The webhook timestamp is invalid or outside the allowed tolerance.');
  Key := DecodeSecret(Secret);
  Prefix := TEncoding.UTF8.GetBytes(Id + '.' + Timestamp + '.');
  SetLength(SignedData, Length(Prefix) + Length(Payload));
  if Length(Prefix) > 0 then Move(Prefix[0], SignedData[0], Length(Prefix));
  if Length(Payload) > 0 then Move(Payload[0], SignedData[Length(Prefix)], Length(Payload));
  Expected := THashSHA2.GetHMACAsBytes(SignedData, Key, THashSHA2.TSHA2Version.SHA256);
  Parts := Signature.Split([',']);
  Matched := False;
  for Candidate in Parts do
    if ConstantTimeSignatureMatch(Expected, Trim(Candidate)) then Matched := True;
  if not Matched then
    raise ERaimsSignatureError.Create('No webhook signature matches the configured secret.');
end;

class function TRaimsWebhook.ConstructEvent(const Payload: TBytes;
  const Headers: TArray<TRaimsHeader>; const Secret: string;
  ToleranceSeconds, NowSeconds: Int64): TJSONObject;
begin
  VerifySignature(Payload, Headers, Secret, ToleranceSeconds, NowSeconds);
  try
    Result := RaimsParseObject(RaimsDecodeUtf8(Payload));
  except
    on E: ERaimsUnexpectedResponseError do
      raise ERaimsSignatureError.Create('The authenticated webhook body must be a valid UTF-8 JSON object.');
  end;
end;

end.
