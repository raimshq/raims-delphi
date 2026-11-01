# Contract and maintenance

## Source and generation

`contracts/openapi.json` preserves the bytes of the public revision identified
in `contracts/source.json`, including its URL, revision, SHA-256 and API version.
The canonical contract belongs to the Public API. The SDK consumes the surface
published in [raimshq/openapi](https://github.com/raimshq/openapi).

```sh
python scripts/generate.py
python scripts/generate.py --check
```

Generation is offline. The generator verifies the contract checksum and
requires `contracts/service-map.json` to cover every published operation exactly
once. It owns models, parameters, resource services, client composition,
constants, operation metadata and `docs/reference.md`. `--check` compares the
expected outputs without changing them.

Pascal units and package files are written with CRLF line endings; Markdown and
JSON outputs use LF. The check accepts either text line ending and still rejects
changes to generated content. The pinned contract keeps its original bytes.
Nullable references are resolved through their alias chains. Unsupported schema
shapes and cyclic aliases fail before generated files are written.
Named response-root aliases preserve their model type and, for list responses,
their pagination loader and typed navigation.
Type and member names are checked against Delphi's case-insensitive symbol
rules, including inherited helpers. JSON operation responses require named,
non-nullable object roots; empty success responses are supported only for
`204`. Other response forms are rejected during generation. Typed additional
properties are checked separately from the object's declared fields.

UTF-8 conversion validates Unicode scalar values in portable Pascal code.
It preserves embedded nulls and supplementary characters, and rejects
malformed UTF-8 and unpaired UTF-16 surrogates. Elapsed request time uses
the RTL's monotonic `TStopwatch` on every target. The runtime gate checks
valid round trips and malformed UTF-8 and UTF-16.

When updating the snapshot, verify the public revision's manifest and checksum.
Review types, nullability, required fields, authentication, environments,
statuses, idempotency and cursors. Regenerate outputs and check consuming code.
Do not change the contract to invent endpoints or bypass API restrictions.

## Organization

| Path | Responsibility |
| --- | --- |
| `src/Raims.Client.pas` | Client configuration, service composition and lifetime |
| `src/Raims.Services.pas` | Generated resource methods |
| `src/Raims.Params.pas` | Generated input types and fluent setters |
| `src/Raims.Models.pas` | Generated response types and nested values |
| `src/Raims.Validation.pas` | Generated validation of success responses against the contract |
| `src/Raims.Constants.pas` | Generated public value constants |
| `src/Raims.Core.pas` | JSON access, ownership, options, errors and cursor helpers |
| `src/Raims.Http.pas` | Transport, read retries and HTTP metadata |
| `src/Raims.Webhooks.pas` | Authentication of the original webhook body |
| `contracts/operations.json` | Generated operation metadata |
| `contracts/delphi-api.json` | Independent public interface baseline |

## Implementation impact

| Behavior | Source | Consumers | Persistence | Required validation |
| --- | --- | --- | --- | --- |
| Delphi public API client | Pinned public contract | Delphi backend applications | No migration | Every operation and success status |
| Types, pagination and pending results | Existing HTTP contract | Generated services and models | None | Serialization, ownership and cursor scenarios |
| Receiving events | Published signing protocol | Integrator backend | Integrator owns event deduplication | Original bytes, clock checks and rotation |
| Public availability guidance | Confirmed distribution and public guides | Existing support catalog | None | Guidance matches the available source |

This SDK does not change Public API contracts or behavior. Existing CLI, MCP
and other SDK consumers remain on the same contract; this client does not
require them to regenerate. The Delphi surface uses API keys and excludes
OAuth-only parameters. It adds no support session states or financial query
tools, so the support context contract does not need a new field for it.

## Local validation

`python scripts/check.py` calls the canonical adapter in
`Developer-Toolkit/scripts/release-preflight/delphi_sdk.py`. Test sources,
fixtures, generated consumers, build outputs and evidence are materialized
exclusively in the workspace's `.tmp/raims-delphi-sdk` directory. The SDK does
not maintain a parallel test suite in its source package.

Use Python 3.12 or newer for the workspace engineering gates, including SAST.
Python is not required by applications consuming the SDK.

The source targets Win32, Win64, Linux64, OSX64, Android, Android64 and
iOSDevice64 with Delphi 10.4 or newer; OSXARM64 requires Delphi 11 and
iOSSimARM64 requires Delphi 11.2. See the
[platform requirements](installation.md#platform-requirements). Source archive
publication and native compatibility have separate validation results.

```sh
python scripts/check.py --source-only
python scripts/check.py --source-release
python scripts/check.py
```

`--source-only` checks development sources and never approves publication.
`--source-release` validates the source archive: contract checksum and
provenance, operation coverage, deterministic generation, public API baseline,
source policies, archive contents, extraction and regeneration. Its approval
applies only to publishing SDK source. The canonical delivery gates also run
the required security scans. These checks do not execute Delphi or certify a
compiled library or native runtime.

The default mode separately compiles and executes Windows consumers. It fails
when the actual Win32 or Win64 compiler is missing. It records the other
declared targets as unverified and does not approve native compatibility
across all targets. Native compatibility claims require actual Delphi builds
and successful runtime scenarios on each claimed target; source inspection,
compiler stubs and another platform's result do not provide that evidence.

Pass `--dcc32` and `--dcc64` with the paths to the actual Delphi compilers when
they are not discoverable. The adapter also checks `RAIMS_WIN32_COMPILER`,
`RAIMS_WIN64_COMPILER`, `PATH`, `BDS`, `BDSROOT` and installed BDS registry
entries. Keep the compiler's licensed runtime and library configuration intact.
The adapter does not install or replace compilers.

The adapter materializes desktop console consumer scenarios in the validation
directory. Mobile host applications are not generated or executed. Native
checks use the extracted source. Windows
checks also build `Raims.dpk` separately; other target applications include
the source units directly. Windows package and consumer builds rebuild the
SDK units with range checks enabled under both Boolean evaluation modes
(`B-` and `B+`). Their outputs stay in the validation directory. Change the
compatibility
baseline only after reviewing the intended public API change; the explicit
`--write-baseline` option does not establish backward compatibility.

Public interface GUIDs are part of that baseline. The canonical suite also
materializes fluent parameter setters, typed response getters and pagination
callbacks, so checking operation coverage does not rely only on raw JSON calls.
Inline object-array consumers inspect their owned JSON objects directly and
free every cloned item after use.

The compatibility baseline covers `Raims.Client`, `Raims.Core`, `Raims.Models`,
`Raims.Params`, `Raims.Services`, `Raims.Constants` and `Raims.Webhooks`.
`Raims.Http` and `Raims.Validation` are implementation units; their classes and
helpers are not covered by the public compatibility guarantee. Consumers can
inject transport through `IRaimsTransport` in `Raims.Core`.

Use isolated transports and loopback servers. Do not call the real financial
API, even with a Sandbox key. Compiled checks must exercise the actual SDK
units and a separate consumer, including requests, ownership, metadata,
pagination, read retries, write-send counts and webhook verification. Stop
temporary processes and confirm that ports are released after validation.

The Python tooling can use the existing Semgrep rules. Delphi source-policy
checks have a narrower scope than a Pascal-aware static security analyzer;
report that distinction. Source or tooling changes invalidate affected evidence.

## Distribution and availability

The SDK is distributed as source, compiled by the consuming application.
Public documentation must describe the source and targets actually available
from a confirmed distribution. Do not advertise a package-manager entry or
release asset before verifying it at the destination.

Repository creation, pushes, tags, releases, executable workflows and runner
configuration require their own authorization. Source validation does not
publish the SDK or configure infrastructure. Run the applicable canonical
delivery gates before an authorized publication and verify the resulting
source archive contents and hashes from the destination. Source publication
does not require installing Delphi on the publishing workstation.

Public guides, support catalogs and the public changelog must use the actual
availability date and confirmed distribution instructions. Keep operational
tracking in the private workspace source outside Git. Do not include its
contents, location or links in this repository or package.
