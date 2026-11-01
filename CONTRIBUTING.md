# Contributing

Read `AGENTS.md` and the [maintenance guide](docs/maintenance.md). Preserve the
pinned public contract and regenerate outputs with `python scripts/generate.py`.
Use `--check` to detect changes without rewriting generated files.

`python scripts/check.py` calls the canonical Developer Toolkit validator.
Use `--source-release` to validate the source archive for publication, together
with the canonical security and delivery gates. `--source-only` is diagnostic
and never approves a release. Neither mode certifies compiled compatibility.
The default mode separately compiles and runs Win32 and Win64 consumers with
actual Delphi compilers; the other declared targets remain unverified.
See [validation modes](docs/maintenance.md#local-validation) and
[platform requirements](docs/installation.md#platform-requirements).

Changes must preserve every published operation and success status, including
empty responses and `202`. Relevant scenarios include:

- Exact integers, omitted fields, explicit null, false, zero and future fields.
- Parameter and response types, nested values and ownership on failure paths.
- Client isolation, per-request options, closure and the documented thread model.
- HTTP methods, escaped paths, queries, body serialization and response metadata.
- TLS, redirects, timeout, response limits and invalid JSON or UTF-8.
- Read retry budgets, `Retry-After` and a single send for every write attempt.
- Cursor navigation, preserved filters, empty pages, cycles and failed reads.
- Original-body webhook signatures, clock checks, rotation and ambiguous headers.
- Redacted diagnostics, source packaging and an independent consuming application.

Keep tests, simulators, consumer projects, tools, builds and evidence exclusively
in `C:\server\raims\.tmp\raims-delphi-sdk`. Use isolated transports and loopback
receivers. Do not call the real API to validate the library, even with a Sandbox
key. Stop temporary processes and confirm that their ports are free.

Review every modified and new file, `git diff` and `git diff --cached`. Preserve
licenses and attribution. Leave changes uncommitted and unstaged. Repository
creation, pushes, releases and publication require separate authorization.
