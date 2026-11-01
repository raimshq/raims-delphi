# Errors, idempotency and retries

Errors derive from `ERaimsException` in `Raims.Core`. Check their category and
`LastResponse` metadata before deciding how the application should proceed.
A timeout or broken connection after sending does not prove that a write was
rejected.

`ERaimsApiError` preserves the API's error code, type and message through
`Code`, `ErrorType` and `ApiMessage`. Specific subclasses distinguish invalid
requests, authentication, permissions, missing resources, conflicts and rate
limits. `ERaimsConnectionError` represents a transport failure;
`ERaimsUnexpectedResponseError` represents an incompatible response.

Exception messages and default object representations omit request contents.
Accessing API error data explicitly can expose sensitive information. Log only
the metadata needed to investigate a failure, such as the status and `Request-Id`.

`ApiError` returns an independent `TJSONObject` copy on each access, or `nil`
when no error object was available. Store that result and free it after use.
It differs from borrowed JSON properties on response models; see
[ownership](usage.md#ownership).

## Idempotency

The SDK does not generate idempotency keys or retry POST, PATCH, PUT or DELETE
automatically. Define and persist one key per intent before calling an operation
that accepts it, then set `TRaimsRequestOptions.IdempotencyKey`.

After losing a response, preserve the key and all parameters, including dates.
Query the resource before creating another intent. Changing parameters or
generating another key can create a different operation. Key validity and
retention follow the API contract; the SDK has no local idempotency cache.

## Read retries

Reads are not retried by default. `MaxNetworkRetries` configures additional
attempts for eligible read failures. Write methods always retain a single SDK
send per call. The transport does not follow redirects.

An available `Retry-After` is subject to the SDK's bounded delay policy. If a
delay cannot be accepted, the failure returns to the application so it can
decide when to resume. A retry budget does not make writes safe to repeat.

Each attempt produces a diagnostic record when a request observer is configured.
Ordinary observer exceptions do not change an operation's result or cause another
write. Fatal memory or access errors propagate to the application.

## Pending responses

HTTP `202` means that the request was accepted with a pending result. Query the
resource and process the relevant events before reporting that a payment,
cancellation or refund completed. `LastResponse.StatusCode` preserves the HTTP
status. `LastResponse.RequestId` and `RetryAfter` preserve available diagnostic
headers, including when the API rejects the request.

Failures raised by an injected transport retain the response metadata that
transport provides. Read retries respect its `Retry-After`; a delay above
30 seconds returns the failure to the application instead of retrying early.
If the native HTTP library fails while receiving the body, it may not expose
the response headers. Metadata that was not available remains empty.
