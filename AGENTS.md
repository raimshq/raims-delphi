# Raims Delphi SDK

Read README, CONTRIBUTING and docs/maintenance.md before changing the SDK.

- Write repository descriptions and Markdown documentation in English.
- Keep internal TODO lists, backlogs and roadmaps out of this public-source
  repository and its packages. Track operational work privately outside Git.
  Do not publish that content, its location or links.
- Target Win32, Win64, Linux64, OSX64, Android, Android64 and iOSDevice64 with
  Delphi 10.4 or newer; OSXARM64 requires Delphi 11 and iOSSimARM64 requires
  Delphi 11.2. Keep operating-system-specific calls out of shared units. Use
  the standard runtime library without third-party Delphi packages or a UI
  framework dependency.
- Consume only the public contract pinned in `contracts`, with its revision
  and SHA-256 verified. Do not import private contracts or host code.
- `scripts/generate.py` owns models, parameters, services, constants, client
  composition, operation metadata and `docs/reference.md`. Regenerate these
  outputs instead of editing them manually. Cover every operation exactly once.
- Preserve JSON names, integer cents, Unix seconds, omission, explicit null,
  unknown response fields and pending responses. Do not generate idempotency
  keys or retry writes automatically. Optional retries apply only to reads.
- API keys determine company and environment. Do not add OAuth, environment
  selection or arbitrary request headers. Preserve TLS validation and block
  redirects. Do not upload files or download external URLs through the
  authenticated API client.
- Define ownership explicitly. Callers own parameters and returned resources.
  JSON passed to setters is copied. Borrowed JSON must not be freed or changed.
- Keep credentials, resource IDs, query strings and payloads out of default
  representations and diagnostics. Preserve `Request-Id` in response metadata.
- Tests, simulators, consumer projects, builds, tools and evidence belong only
  in `C:\server\raims\.tmp\raims-delphi-sdk`, outside this repository and packages.
  Use isolated transports and loopback receivers; do not call the real API.
- `scripts/check.py` calls the canonical Developer Toolkit validator.
  `--source-only` is diagnostic and never approves release. `--source-release`
  validates a source archive for source publication; run the canonical security
  and delivery gates as well. It does not certify compilation or runtime.
  Native checks are separate and require actual Delphi compilers. The default
  mode builds and runs Win32 and Win64 consumers; it records the other targets
  as unverified. Do not replace Delphi with compiler stubs or claim native
  compatibility from source inspection or another platform's result.
- Stop temporary validation processes and confirm that their ports are free.
- Describe Raims features directly and preserve required licenses and
  attribution. Apply the humanizer skill to text intended for people.
- Leave local changes uncommitted and unstaged. Repository creation, pushes,
  releases, package publication, public guides and infrastructure changes each
  require their own authorization.
