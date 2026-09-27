# Security Policy

## Supported versions

Only the latest released version of tcs.openapi receives security fixes.

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report them privately through
[GitHub security advisories](https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.openapi/security/advisories/new).
Include the affected version, the steps to reproduce and the impact you expect.

You should get a first response within 7 days.

## Scope notes

- `Protect-ConfigValue` / `Unprotect-ConfigValue` protect values at rest. They do not protect
  against code already running as the same user (CurrentUser scope) or as any local user
  (LocalMachine scope).
- Telemetry never sends user names, machine names, paths, hardware identifiers or error
  messages. Report anything that suggests otherwise as a security issue.
