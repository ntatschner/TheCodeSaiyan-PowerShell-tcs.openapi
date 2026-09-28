# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en-GB/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Fixed

- Under `$WhatIfPreference = $true`, `Invoke-OpenApiRequest` dropped the caller's `-Verbose`, `-Debug`
  and `-WarningAction` and printed a "What if: Set variable" line for each, and the engine kept no
  module state between calls (contexts, HTTP clients, OAuth tokens). `Set-Variable` honours `-WhatIf`,
  so the engine now calls it with `-WhatIf:$false`. A read such as a generated `Get-` command runs
  as it would without `$WhatIfPreference`, and commands with `-WhatIf` still stop before the request.

### Changed

- The generated README no longer says that commands pass `-WhatIf` through to the engine; it says
  that the commands that can change data have `-WhatIf` and `-Confirm`.

## [0.2.2] - 2026-09-28

### Fixed

- Generated `Get-` and `Test-` commands no longer have `-WhatIf` and `-Confirm` when their operation
  uses POST, PUT or PATCH. An operationId that starts with get, list, find, search or query (`Get-`),
  or validate, check or verify (`Test-`), is a read that some APIs send with a body, such as the
  UniFi Site Manager `POST /v1/isp-metrics/{type}/query` (`Get-UniFiIspMetricQuery`). Such a command
  now runs under `$WhatIfPreference = $true` like any other read. DELETE operations and the verbs
  that change state (`New`, `Set`, `Remove`, `Start`, `Stop`, `Restart`, `Reset`, `Update`) keep
  `-WhatIf` and `-Confirm` whatever their name, and so do all other verbs on POST, PUT and PATCH
  (`Invoke`, `Send`, `Submit`, `Export`, ...). Regenerate a module with `-Force` to pick this up.

### Changed

- The README, `about_tcs.openapi`, the `New-OpenApiModule` help and the generated README describe
  which commands get `-WhatIf` and `-Confirm`.

## [0.2.1] - 2026-09-27

### Changed

- Requires tcs.core 0.4.1 or later.
- Telemetry: `Get-OpenApiContext`, `Set-OpenApiContext`, `Remove-OpenApiContext`,
  `Import-OpenApiDocument`, `New-OpenApiModule` and `Test-OpenApiDocument` record their run with
  `Start-TcsTelemetry` / `Complete-TcsTelemetry` directly instead of through `Invoke-TcsCommand`,
  which tcs.core 0.5.0 removes. Their errors and warnings now come from the command itself: error
  IDs end in the command's name (for example `OpenApi.ContextNotFound,Get-OpenApiContext` instead
  of `,Invoke-TcsCommand`), and `-ErrorVariable` (also with `-ErrorAction SilentlyContinue`),
  `-WarningVariable` and `-InformationVariable` collect them.
- A pipeline into `Import-OpenApiDocument` or `Test-OpenApiDocument` that a later command stops
  (for example `Select-Object -First`) still records its telemetry.

## [0.2.0] - 2026-09-27

### Added

- Catch-all path segments: a final router-style segment such as `/v1/connector/consoles/{id}/*path` (or
  `{path*}`) whose name is a path parameter becomes `{path}` in the model and the parameter is flagged
  `CatchAll`. The engine keeps the slashes of a `CatchAll` (or `allowReserved`) path value and escapes each
  segment, so `-Path 'proxy/network/integration/v1/sites'` reaches `.../consoles/<id>/proxy/network/integration/v1/sites`.
- Token paging (`Paging.Kind = 'token'`): a `nextToken`, `pageToken`, `next_token`, `page_token`, `cursor`,
  `continuationToken` or `continuation_token` query parameter with a response object that has one array and the
  next token (`nextToken`, `nextPageToken`, `next_cursor`, `nextCursor`, ... or the parameter's name). The
  commands output the items and get `-All`, which repeats the request with each response's token until it is
  empty or repeats.
- `New-OpenApiModule -UnwrapProperty <name>` (for example `data`): commands whose 2xx JSON response is an object
  with that property output its value instead of the whole response, typed with the property's schema name.
  Stored per operation as `UnwrapProperty` in `OpenApi/operations.json`; not applied with `-Raw` or to pageable
  operations.
- `Test-OpenApiDocument` findings OA023 (path parameter that is not in the path template, Warning) and OA024
  (path template placeholder without a path parameter, Error).
- The UniFi Site Manager API document as a fixture, with an end-to-end test of the module generated from it.

### Changed

- Naming: when the noun from an operationId ends with the operation's own HTTP method word and other words
  remain, the word is dropped: `ConnectorGet` -> `Get-<Prefix>Connector`, `ConnectorPost` -> `New-`,
  `ConnectorPut` -> `Set-`, `ConnectorPatch` -> `Update-`, `ConnectorDelete` -> `Remove-<Prefix>Connector`.
  Regenerating a module from such a document renames those commands.
- The generated README (and the `Set-<Prefix>Context` example) shows the credential parameters of the
  document's security schemes (`-ApiKey`, `-Credential`, `-BearerToken` or `-ClientId`/`-ClientSecret`) instead
  of always `-BearerToken`, and `-BaseUri` only when the document has no default server.
- Generated modules require tcs.openapi 0.2.0. Metadata written by 0.1.x keeps working: a missing `CatchAll`,
  token paging or `UnwrapProperty` means the earlier behaviour.

### Fixed

- `Test-OpenApiDocument -InformationAction Ignore` threw on Windows PowerShell 5.1 ("The value Ignore is not
  supported for an ActionPreference variable") for a document without findings.
- `-WarningAction Ignore` on a generated command (or on `Invoke-OpenApiRequest`) no longer makes the engine's own
  warnings (for example when paging stops) throw on Windows PowerShell 5.1.
- A path parameter value such as `proxy/network/...` of a catch-all path was sent as a literal `*path` segment
  and the value was dropped.

## [0.1.1] - 2026-09-27

### Added

- `Test-OpenApiDocument -Summary` returns one `Tcs.OpenApi.TestSummary` object (Source, SourceVersion, Operations,
  Errors, Warnings, Information, IsValid, Findings), also when the document has no findings.

### Changed

- `Test-OpenApiDocument` writes `No problems found in <source> (<n> operations).` to the information stream (shown by
  default) when a document has no findings, so an empty result is not mistaken for the command doing nothing.
  `-InformationAction Ignore` drops it.

## [0.1.0] - 2026-09-27

First release. Replaces the Swagger generator of tcs.utils.

### Added

- `Import-OpenApiDocument`: reads OpenAPI 3.0/3.1 and Swagger 2.0 documents (JSON; YAML with powershell-yaml) from a
  file, URL or string into one OpenAPI 3-shaped model: local `$ref` resolution with circular-schema detection,
  allOf merging, 3.1 type arrays, Swagger 2.0 conversion (servers, bodies, formData, collectionFormat, security
  definitions) and paging detection (`x-ms-pageable`, nextLink properties, `Link` headers).
- `Test-OpenApiDocument`: findings (OA001-OA070) for invalid structure and unsupported features; never throws for
  document problems.
- `New-OpenApiModule`: writes a module with one wrapper command per operation, `Set-/Get-/Remove-<Prefix>Context`,
  operation metadata, the normalised document, a README and a never-overwritten `Overrides.ps1`. Deterministic
  output; `-WhatIf`, `-Force`; every generated function is parsed and bound before it is written.
- Naming from `x-ps-name`/`x-ps-verb`/`x-ps-noun` or the operationId, approved verbs only, collision renames
  (OA040), parameter renames (OA041), and no command that shadows a core PowerShell command such as `Get-Item`
  (OA042).
- `Set-OpenApiContext`, `Get-OpenApiContext`, `Remove-OpenApiContext`: per-service connections with api key, basic,
  bearer and OAuth2 client-credentials authentication, headers, timeout, proxy, certificate bypass and retries;
  `-Persist` through tcs.core `Set-ModuleSecret`; secrets masked on display.
- `Invoke-OpenApiRequest`: the request engine (one `HttpClient` per service on 5.1 and 7): path/query/header/cookie
  serialisation with every OpenAPI style, JSON/form/multipart/binary/text bodies, retry with `Retry-After`,
  `-All` paging that streams items, typed JSON output, `-OutFile` downloads, `-Raw`, problem+json errors as
  `OpenApi.<Service>.<Status>` error records through the calling command, deprecation warnings and redacted
  debug logging.
- `about_tcs.openapi` help (en-GB, en-US), unit, snapshot and end-to-end tests (generated modules called against a
  local HTTP server), CI smoke tests.
