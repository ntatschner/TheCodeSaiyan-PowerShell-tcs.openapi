# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en-GB/1.1.0/) and the project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
