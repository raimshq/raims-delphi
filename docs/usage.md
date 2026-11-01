# Using the client

## Configuration

```delphi
Options := TRaimsClientOptions.Default;
Options.TimeoutMilliseconds := 80000;
Options.MaxNetworkRetries := 0;

Client := TRaimsClient.Create(
  GetEnvironmentVariable('RAIMS_API_KEY'), Options);
```

`TRaimsClientOptions` is defined in `Raims.Core`. The defaults are 80-second
native connection, send and receive timeouts, no read retries and a 16 MiB
response limit. These are native phase timeouts, not a total operation deadline.
Keep the client open for the scope that uses its services and free it when
that scope ends.

The configurable timeout is between 1 and 300000 milliseconds. Read retries
accept zero to five additional attempts. `MaxResponseBytes` can reduce the
response limit and cannot exceed 16777216 bytes.

The default API origin is `https://api.raims.com`. TLS validation remains
enabled and redirects are blocked. The authenticated client does not transfer
external files. The API key determines company, environment and permissions.
The SDK does not expose environment selection, OAuth or arbitrary headers.

`ApiBase` accepts an HTTPS origin without credentials, path, query or fragment.
HTTP is accepted only for loopback validation.

`TRaimsRequestOptions.Default` creates per-request options. These allow an API
key, idempotency key, timeout and read retry override. A per-request API key
affects only that request; the application must preserve the correct company
and environment. Initialize options through `Default` before changing fields.

## Threads and closure

Requests are synchronous. In a visual application, run network calls and
`Close` on a worker thread so the desktop or mobile UI can keep responding.
Send UI updates through your framework's main-thread mechanism and keep the
client alive until the worker finishes.

A client serializes its requests. Use separate clients when your backend needs
parallel sends. Parameters are mutable; do not change them while a call is
preparing or using them.

`Close` rejects new calls and wakes operations waiting between read attempts.
It waits for an active native HTTP call to return under its configured timeouts
before releasing the transport. It does not promise an immediate network abort.
Closure can be repeated; freeing the client also closes it. Do not free a client
or its service objects while another thread is using them.

## Parameters and responses

Typed parameters are in `Raims.Params`. Create a parameter object and use its
fluent setters. Omitting a setter leaves the field absent. The generated
`Set<Field>Null` method sends explicit null where the contract permits it.
`Unset` removes a field. Check the API's update behavior before sending null:
its meaning differs from omitting a value.

Zero, false, empty arrays and empty objects are preserved. Cents and Unix seconds
use `Int64` and are serialized without conversion to floating point. Value
constants are in `Raims.Constants`; the application can also receive future
values. Response models are in `Raims.Models`.

`HasField('name')` distinguishes an absent field from a present value.
`IsNull('name')` identifies explicit JSON null. Scalar getters return their
Delphi default for absent or null values, so check presence and null before
interpreting an optional zero, false or empty string.

`ToJson` returns a JSON string. `RawJson` returns an independent `TJSONObject`
containing received fields, including future fields. Default `ToString`
representations omit the object's contents. Treat explicit JSON access as
sensitive data.

When an operation supports different responses by status, its result model
exposes the available fields. Check `LastResponse.StatusCode` and field
presence before using a field specific to one result. `202` remains pending.
A successful empty response still retains HTTP metadata.

## Ownership

The API uses ordinary Delphi object ownership:

| Value | Owner and lifetime |
| --- | --- |
| `TRaimsClient` | The application frees it after use. |
| Services exposed by the client | The client owns them; do not free them. |
| Parameter objects | The caller frees them after the call. |
| Returned resources and pages | The caller frees them. |
| Typed nested objects | Each getter creates a copy; the caller frees it. |
| Typed arrays of objects | The caller frees every item, including JSON object clones. |
| Scalar arrays | Delphi manages the array's memory. |
| `RawJson` result | The caller owns and frees the copy. |
| `GetObject` and `GetArray` results | Borrowed from their parent; do not free or mutate them. |
| Response-model properties returning `TJSONObject` or `TJSONArray` directly | Borrowed from their parent; do not free or mutate them. |
| `ERaimsApiError.ApiError` | Each access returns an owned copy, or `nil`; the caller frees the copy. |

JSON objects passed to parameter setters are copied. The caller retains the
original and can free it after the setter returns. A borrowed nested JSON value
is valid only while its parent exists and remains unchanged. Use `RawJson` or
clone a value when it must outlive the parent.

When a getter returns an owned object, each access creates a separate copy.
Store it in a local variable and free it with `try/finally`. Borrowed JSON
properties follow the separate rules in the table.

For error JSON, retrieve the copy once and free that same object:

```delphi
ErrorDetails := E.ApiError;
try
  if ErrorDetails <> nil then InspectError(ErrorDetails);
finally
  ErrorDetails.Free;
end;
```

Here `E` is an `ERaimsApiError` caught by the application, `ErrorDetails` is a
`TJSONObject`, and `InspectError` belongs to the application. The copy can
contain sensitive error data. Freeing it does not change the exception's data.

## Pagination

List responses retain cursor metadata and a loader for the original request.
`NextPage` and `PreviousPage` return a new page or `nil` when navigation is
unavailable. The caller owns each returned page. Filters, credentials and
request options remain associated with navigation. Keep the client open.

`AutoPagingEach` reads subsequent pages as it processes items, up to the caller's
limit. Its callback receives a borrowed `TJSONObject`. Do not free or mutate
that value, and copy it before retaining it beyond the callback.

```delphi
Customers.AutoPagingEach(
  procedure(Customer: TJSONObject)
  begin
    ProcessCustomer(Customer);
  end,
  1000);
```

This example uses `System.JSON`; `ProcessCustomer` belongs to the application.
The application still frees the first `Customers` page. The helper owns the
additional pages it fetches. Cursor inconsistencies raise an error instead
of allowing an endless traversal. A failed explicit page read leaves the
original page available for another attempt.

## Files and uploads

Receipts, boleto documents and upload permissions are API metadata. The SDK
does not download their URLs, upload files or forward the Bearer key to those
destinations. Transfer files separately using the procedure and headers
returned by the API.

## Diagnostics

`RequestObserver` receives the method, parameterized path, duration, attempt,
status and `Request-Id`. It does not include resource IDs, query strings,
payloads or credentials. Ordinary observer exceptions do not change the
operation's result or trigger another write. The SDK sends no external telemetry
or alerts.
