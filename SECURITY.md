# Security

Use the SDK in your backend service and keep API keys and webhook secrets in
protected storage. Do not embed them in distributed desktop applications or
log credentials, bodies, personal documents or temporary links. `ToJson` and
`RawJson` explicitly expose resource contents; handle them as sensitive data.

The transport validates TLS and blocks redirects. It does not upload files,
download external links or forward the API key to those links. The key
determines the company and environment; the API enforces permissions and
financial rules. Authenticate webhook signatures before processing an event
and deduplicate events in durable storage.

Report vulnerabilities to `security@raims.com`, including the source revision
or version, impact and a minimal reproduction without real data. Do not send
keys or customer information or publish those details in public issues.
