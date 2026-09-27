# Publishing tcs.openapi to the PowerShell Gallery

Publishing uses the shared workflows in
[ntatschner/tcs-shared-workflows](https://github.com/ntatschner/tcs-shared-workflows). This repository only calls them.

| Workflow | Trigger | What it does |
|---|---|---|
| `ci-validate.yml` | push / pull request to `main` | Shared validation (manifest, PSScriptAnalyzer, RequiredModules, import, `.github/scripts/module-smoke-tests.ps1`), the lint job with the repository settings, and Pester on pwsh (Ubuntu, Windows, macOS) and Windows PowerShell 5.1 |
| `create-version-tag.yml` | after a successful CI run on `main` | Creates `v<ModuleVersion>` when the manifest version is newer than the latest tag |
| `publish-to-psgallery.yml` | a `v*` tag, or manually | Validates and publishes `modules/tcs.openapi`, then creates a GitHub release |
| `generate-docs.yml` | after CI on `main`, pull requests | PlatyPS help in `docs/` (en-GB) |

## Prerequisites

1. **PowerShell Gallery API key** with the "Push new packages and package versions" scope for `tcs.openapi`.
2. **Repository secret** `PSGALLERY_API_KEY` (Settings -> Secrets and variables -> Actions) holding that key.
3. **tcs.core 0.4.0 or later on the PowerShell Gallery.** tcs.openapi declares
   `RequiredModules = @(@{ ModuleName = 'tcs.core'; ModuleVersion = '0.4.0' })`. The Gallery refuses a module whose
   required modules it does not have, and every CI job that imports tcs.openapi installs tcs.core first (the Pester
   jobs install exactly 0.4.0; the shared validate workflow's "Resolve RequiredModules" step installs the latest).
   tcs.core 0.4.0 is already published.

## Releasing a version

```powershell
./Build.ps1 -Task PrepareRelease -Version 0.2.0   # updates the manifest, validates and runs the tests
```

Then add the `CHANGELOG.md` entry, open a pull request and merge it. On `main`, CI runs, `create-version-tag.yml`
creates the `v0.2.0` tag and the tag starts `publish-to-psgallery.yml`. To publish by hand, push the tag yourself
(`git tag v0.2.0; git push origin v0.2.0`) or run "Publish to PowerShell Gallery" from the Actions tab (with
"Force publish" only to replace a version that failed half way).

## Notes

- The manifest lists `RequiredAssemblies = @('System.Net.Http')`. `Test-ModuleManifest` checks that entry against
  the Windows GAC, so it reports it as invalid on Linux and macOS although the module imports everywhere; the shared
  workflows run on Windows, and `Build.ps1` and `tests/Module.Tests.ps1` ignore that one error elsewhere.
- Generated modules require tcs.openapi with a minimum version equal to the generator's version. A tcs.openapi
  release must keep existing generated modules working (operation metadata format and engine parameters).
- Never commit API keys; rotate the Gallery key regularly.

## Troubleshooting

| Problem | Fix |
|---|---|
| "API key invalid" | Check the secret name `PSGALLERY_API_KEY`, its scope and expiry |
| "Version already exists" | Raise `ModuleVersion` in `tcs.openapi.psd1` |
| Import fails in CI with a missing tcs.core | tcs.core 0.4.0 is not on the Gallery, or the install step failed |
| PSScriptAnalyzer failures | Run `./Build.ps1 -Task Validate` locally and fix the findings |
