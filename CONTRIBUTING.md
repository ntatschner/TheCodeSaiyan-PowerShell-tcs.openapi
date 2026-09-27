# Contributing to tcs.openapi

tcs.openapi generates PowerShell modules from OpenAPI documents and is the runtime those modules use. Generated
modules call the exported engine commands (`Invoke-OpenApiRequest`, `Set-/Get-/Remove-OpenApiContext`) and read the
operation metadata format described in `DESIGN.md`, so changes to either affect every generated module.

## Getting started

Requirements: PowerShell 7.2+ for development (the code itself must also run on Windows PowerShell 5.1), tcs.core
0.4.0, Pester 5.7.1 and PSScriptAnalyzer 1.23.0. The build script installs Pester and tcs.core when they are missing.

```powershell
./Build.ps1 -Task Test             # manifest check, PSScriptAnalyzer, Pester
./Build.ps1 -Task Validate         # manifest check and PSScriptAnalyzer only
./Build.ps1 -Task UpdateSnapshots  # regenerate tests/Snapshots
```

## Layout

| Path | Contents |
| --- | --- |
| `modules/tcs.openapi/Public/` | Exported commands, one per file, named after the function |
| `modules/tcs.openapi/Private/Document/` | Loading, Swagger 2.0 conversion, `$ref` resolution, normalisation, findings |
| `modules/tcs.openapi/Private/Generator/` | Naming, parameter model, rendering, the generation plan and writer |
| `modules/tcs.openapi/Private/Runtime/` | Context store, auth, serialisation, bodies, paging, errors |
| `modules/tcs.openapi/Templates/` | Templates of the generated module files |
| `modules/tcs.openapi/en-GB/`, `en-US/` | `about_tcs.openapi.help.txt` (the two copies must be identical) |
| `<folder>/Tests/<Function>.Tests.ps1` | Unit tests, next to the code |
| `tests/` | Module guards (`Module.Tests.ps1`), runtime and end-to-end tests, snapshots, fixtures and helpers |

`tests/Module.Tests.ps1` checks that `FunctionsToExport` equals the `Public/*.ps1` files, that every function uses
an approved verb, is defined once and has a test file, that public commands have full help, that the module imports
silently and that non-ASCII files have a BOM.

## Snapshots

`tests/Snapshots/<case>/<Module>` holds the expected output of the generator for three hand-built document models
(`tests/Helpers/New-TestOpenApiModel.ps1`); `tests/Generator.Snapshot.Tests.ps1` compares fresh output byte for byte.
After a deliberate change to the generator or `Templates/`, run `./Build.ps1 -Task UpdateSnapshots` (or
`tests/Helpers/Update-Snapshots.ps1`), review `git diff tests/Snapshots` and commit the snapshots with the change.
A snapshot diff you did not expect is a bug.

## End-to-end tests

`tests/EndToEnd.*.Tests.ps1` import a fixture from `tests/Fixtures`, generate a module into `TestDrive`, import it
with the repository's tcs.openapi and call it against `tests/Helpers/TestHttpServer.ps1` (an `HttpListener` on the
loopback address). Add a case there for every behaviour that crosses the generator/runtime boundary.

## Standards

- **Compatibility:** Windows PowerShell 5.1 and PowerShell 7 on Windows, Linux and macOS. No PS7-only syntax (`??`,
  `?:`, `&&`, `||`, `-Parallel`, 3-argument `Join-Path`), no PowerShell classes, no .NET Core-only APIs without a
  5.1 fallback. CI runs the tests on all four.
- **Style:** one function per file, 4-space indentation, `CmdletBinding()`, `OutputType()`, approved verbs, full
  command names and named parameters. PSScriptAnalyzer runs with `PSScriptAnalyzerSettings.psd1` and **warnings
  fail the build**; suppress a rule only with a written justification.
- **State-changing functions** support `-WhatIf`/`-Confirm`.
- **Help:** every exported function has comment-based help with a synopsis, description, every parameter and at
  least one example; private functions have a short synopsis.
- **Tests:** new behaviour and bug fixes come with Pester tests in the layer that owns them. Tests must not touch
  the real user profile or the network: set `TCS_CONFIG_ROOT` to `$TestDrive`.
- **Encoding:** files with non-ASCII characters are UTF-8 with a BOM.
- **Versioning:** [Semantic Versioning](https://semver.org). Record changes in `CHANGELOG.md`. A change to the
  operation metadata format or the engine's parameters must keep existing generated modules working.

## Releasing

1. `./Build.ps1 -Task PrepareRelease -Version x.y.z`
2. Update `CHANGELOG.md`, open a pull request and merge it to `main`.
3. CI creates the `vx.y.z` tag when the manifest version is newer than the latest tag, and the tag triggers
   publishing to the PowerShell Gallery (see `.github/PUBLISHING.md`).
