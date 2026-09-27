# Contributing to tcs.openapi

tcs.openapi is the shared base for the other tcs modules (tcs.azure, tcs.confluence, tcs.jira,
tcs.intune.packaging and tcs.utils). Changes to exported functions can affect all of them.

## Getting started

Requirements: PowerShell 7.2+ for development. Pester 5.7.1 and PSScriptAnalyzer are
installed by the build script when missing.

```powershell
./Build.ps1 -Task Test      # manifest check, PSScriptAnalyzer, Pester
./Build.ps1 -Task Validate  # manifest check and PSScriptAnalyzer only
```

## Layout

| Path | Contents |
| --- | --- |
| `modules/tcs.openapi/Public/` | Exported functions, one per file, named after the function |
| `modules/tcs.openapi/Private/` | Internal helpers (not exported) |
| `modules/tcs.openapi/Public/Tests/` | Pester tests, `<Function>.Tests.ps1` |
| `modules/tcs.openapi/Config/` | Default settings shipped with the module |
| `tests/` | Module-wide tests (manifest, exports, help, PSScriptAnalyzer) |

Every file in `Public/` must also be listed in `FunctionsToExport` in `tcs.openapi.psd1`;
`tests/Module.Tests.ps1` checks this.

## Standards

- **Compatibility:** code must run on Windows PowerShell 5.1 and PowerShell 7 on Windows,
  Linux and macOS. Avoid PS7-only syntax (`??`, `?:`, `&&`, `ForEach-Object -Parallel`) and
  .NET Core-only APIs. CI runs the tests on all four.
- **Style:** 4-space indentation, `CmdletBinding()` on every function, approved verbs,
  full command names (no aliases). PSScriptAnalyzer runs with `PSScriptAnalyzerSettings.psd1`
  and **warnings fail the build**. Suppress a rule only with a written justification.
- **State-changing functions** (`New-`, `Set-`, `Remove-` ...) support `-WhatIf`/`-Confirm`.
- **Help:** every exported function has comment-based help with a synopsis, description,
  every parameter and at least one example.
- **Tests:** new behaviour and bug fixes come with Pester tests. Tests must not touch the real
  user profile or network: set `TCS_CONFIG_ROOT` to `$TestDrive` and mock external calls.
- **Versioning:** [Semantic Versioning](https://semver.org). Record changes in `CHANGELOG.md`.
  Breaking changes to exported functions need matching updates in the other tcs modules.

## Releasing

1. `./Build.ps1 -Task PrepareRelease -Version x.y.z`
2. Update `CHANGELOG.md`, open a pull request and merge it to `main`.
3. CI creates the `vx.y.z` tag when the manifest version is newer than the latest tag, and
   the tag triggers publishing to the PowerShell Gallery.
