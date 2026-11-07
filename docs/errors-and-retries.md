# Errors, idempotency and retries

Errors derive from `ERaimsException` in `Raims.Core`. Check their category and
`LastResponse` metadata before deciding how the application should proceed.
A timeout or broken connection after sending does not prove that a write was
rejected.

`ERaimsApiError` exposes `error.code`, `error.message` and `error.details`
through `Code`, `ApiMessage` and `Details`. Use `Code` to handle the error;
`ApiMessage` is diagnostic text and can change. Specific subclasses distinguish
invalid requests, authentication, permissions, missing resources, conflicts and
rate limits. `ERaimsConnectionError` represents a transport failure;
`ERaimsUnexpectedResponseError` represents an incompatible response.

Exception messages and default object representations omit request contents.
Accessing API error data explicitly can expose sensitive information. Log only
the metadata needed to investigate a failure, such as the status and `Request-Id`.

`Details` returns an independent `TJSONArray` copy containing the field errors,
or `nil` when the response has no details array. Each item contains `field`,
`code` and `message`. General errors can omit this array.

`ApiError` returns an independent `TJSONObject` copy of the complete error on
each access, or `nil` when no error object was available. Store either result
and free it after use. These copies differ from borrowed JSON properties on
response models; see [ownership](usage.md#ownership).


## Migrating error handling from 0.1

Version 0.2 removes `ErrorType`. Use `Code` to choose how to handle an API
error, `ApiMessage` for its diagnostic message, and `Details` for field
validation failures. Each `Details` access returns an owned copy; free it
after use.

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
