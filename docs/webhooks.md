# Receiving webhooks

Authenticate the original bytes before interpreting or processing an event.
`TRaimsWebhook` in `Raims.Webhooks` uses `webhook-id`, `webhook-timestamp` and
`webhook-signature`. Use the `secret_key` returned when creating or rotating
the webhook. This signing secret differs from the API key; keep it in
protected storage.

```delphi
uses
  System.JSON, Raims.Core, Raims.Webhooks;

SetLength(Headers, 3);
Headers[0] := TRaimsHeader.Create('webhook-id', ReceivedDeliveryId);
Headers[1] := TRaimsHeader.Create('webhook-timestamp', ReceivedTimestamp);
Headers[2] := TRaimsHeader.Create('webhook-signature', ReceivedSignature);

Event := TRaimsWebhook.ConstructEvent(RawBody, Headers, WebhookSecret);
try
  ProcessEvent(Event);
finally
  Event.Free;
end;
```

`RawBody` is a `TBytes` containing exactly the bytes received by your server;
`Headers` is a `TArray<TRaimsHeader>` and `Event` is a `TJSONObject` owned by
the caller. `ProcessEvent` belongs to the application. Whitespace, Unicode and
line breaks are part of the signature. Do not parse and reserialize the body
before verification.

Preserve signing header occurrences when building the header array. Header
names are case-insensitive, and repeated or missing signing headers are
rejected. Do not select one value from repeated headers before verification.
Multiple `v1=` signatures can coexist in one `webhook-signature` value during
rotation.

`VerifySignature` authenticates without parsing the body. `ConstructEvent`
also requires a valid UTF-8 JSON object. Both raise `ERaimsSignatureError`
when verification fails. A valid signature does not validate event data or
prevent the same event from being delivered again.

The default tolerance is 300 seconds into the past or future. Keep the server
clock synchronized. Zero tolerance requires the same second; it does not
disable timestamp protection.

Before returning success, check the event type, environment and resource,
and persist the work durably. Deduplicate by the body's `id`; `webhook-id`
identifies the delivery and does not replace the event ID. If persistence
fails, return an HTTP error so another delivery can occur. The event's
`created_at` uses ISO 8601, while the signing header uses Unix seconds.

See the [receiving guide](https://docs.raims.com/en/integracoes/webhooks/receber-eventos).
