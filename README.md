# tcs.openapi

Generate PowerShell modules from OpenAPI 3.0/3.1 and Swagger 2.0 documents, and call them through one
shared request engine.

tcs.openapi has two halves:

- **Generator** (`Import-OpenApiDocument`, `Test-OpenApiDocument`, `New-OpenApiModule`): reads a document,
  normalises it, reports problems as findings and writes a module with one thin wrapper command per operation.
- **Runtime** (`Set-/Get-/Remove-OpenApiContext`, `Invoke-OpenApiRequest`): the engine every generated module
  calls for authentication, parameter serialisation, request bodies, retry, paging, errors and downloads.
  Generated modules list `tcs.openapi` in `RequiredModules`, so an engine fix reaches every generated module
  without regenerating it.

It replaces the Swagger generator that used to live in tcs.utils. The architecture is described in
[DESIGN.md](DESIGN.md).

## Install

```powershell
Install-Module tcs.openapi -Scope CurrentUser   # also installs its RequiredModule tcs.core (0.4.0 or later)
```

Requirements: Windows PowerShell 5.1 or PowerShell 7 (Windows, Linux, macOS) and tcs.core 0.4.0. YAML
documents need [powershell-yaml](https://www.powershellgallery.com/packages/powershell-yaml)
(`ConvertFrom-Yaml`); JSON needs nothing else.

## Quick start

```powershell
# 1. Check the document: errors, and features the generator or runtime do not support
Test-OpenApiDocument -Path ./petstore.json | Where-Object Severity -NE 'Information' | Format-Table Severity, Code, Message

# 2. Generate the module. Always pass -NounPrefix (see "Naming")
$result = New-OpenApiModule -Path ./petstore.json -ModuleName PetStore -NounPrefix PetStore -OutputPath ./out
$result.Findings | Where-Object Severity -NE 'Information'

# 3. Import it (tcs.openapi is loaded as its RequiredModule)
Import-Module ./out/PetStore/PetStore.psd1

# 4. Connect: -BaseUri defaults to the first absolute server URL of the document
Set-PetStoreContext -ApiKey (Read-Host -AsSecureString -Prompt 'API key')

# 5. Call it
Get-PetStorePet -Status available -All
Get-PetStorePetById -PetId 7
New-PetStorePet -Name 'Rex' -Category @{ id = 1; name = 'dogs' } -WhatIf
```

`New-OpenApiModule -WhatIf` shows what would be written; `-Uri` reads the document from a URL; `-Document`
takes a model from `Import-OpenApiDocument`. The result lists the functions, the findings and the skipped
operations.

## The generated module

```
<OutputPath>/<ModuleName>/
  <ModuleName>.psd1                RequiredModules tcs.openapi (minimum = the generator's version); FunctionsToExport listed
  <ModuleName>.psm1                loads OpenApi/operations.json, dot-sources Public/**/*.ps1, then Overrides.ps1
  OpenApi/operations.json          operation metadata the engine uses (method, path, parameter styles, security, paging ...)
  OpenApi/source.json              the normalised document, for diffs between regenerations
  Public/<Tag>/<Verb>-<Noun>.ps1   one command per operation (first tag; untagged -> Public/Default)
  Public/_Connection/              Set-, Get- and Remove-<Prefix>Context
  Overrides.ps1                    yours: created once, never overwritten
  README.md                        the command list
```

The same document and options always give byte-identical files. Existing generated files are replaced only with
`-Force` (which also removes command files for operations that are gone). Every command has comment-based help
built from the document, `[CmdletBinding()]`, `-WhatIf`/`-Confirm` for every method except GET/HEAD/OPTIONS
(`ConfirmImpact = 'High'` for DELETE), and `-Raw`; pageable operations get `-All` and binary responses `-OutFile`.
JSON object bodies are flattened into one parameter per writable top-level property (nested objects as
`[hashtable]`), with `-Body` as an alternative parameter set for the whole body.

### Overrides.ps1

`Overrides.ps1` is dot-sourced after the generated commands, so a function defined there replaces the generated
command of the same name and is exported in its place. It survives `New-OpenApiModule -Force`. Functions with new
names are not exported (the manifest lists the generated names), so use them as helpers. Inside the file,
`$script:TcsOpenApiService` and `$script:TcsOpenApiOperations['<operationId>']` are available for calling
`Invoke-OpenApiRequest` yourself:

```powershell
function Get-PetStorePetById {
    [CmdletBinding()]
    param([Parameter(Mandatory)][long]$PetId)
    Invoke-OpenApiRequest -Service $script:TcsOpenApiService -Operation $script:TcsOpenApiOperations['showPetById'] `
        -PathParameters @{ petId = $PetId } -Cmdlet $PSCmdlet | Select-Object -Property id, name
}
```

## Connections and authentication

`Set-<Prefix>Context` is `Set-OpenApiContext -Service <ModuleName>`: the service name is the module name. It
takes `-BaseUri`, credentials, `-Header` (extra headers for every request), `-TimeoutSec`, `-Proxy`,
`-ProxyCredential`, `-SkipCertificateCheck`, `-MaxRetries`, `-Persist` and `-PassThru`.

| Security scheme | Context parameters |
|---|---|
| `apiKey` in header, query or cookie | `-ApiKey <SecureString>` |
| `http` basic | `-Credential <PSCredential>` |
| `http` bearer | `-BearerToken <SecureString>` |
| `oauth2` clientCredentials | `-ClientId`, `-ClientSecret <SecureString>`, optional `-TokenUri` (defaults to the flow's tokenUrl) and `-Scope` (defaults to the requirement's scopes) |
| `oauth2` (any flow) or `openIdConnect` with a token you already have | `-BearerToken` (a bearer token wins over client credentials) |

For each request the engine takes the operation's security requirements (the document default when the operation
has none) and uses the first requirement whose schemes all have credentials in the context. `security: []` sends
no credentials. OAuth2 tokens are cached until 60 seconds before they expire and requested again once when the API
answers 401.

## Paging, downloads and raw responses

- **Paging**: operations marked with `x-ms-pageable`, or whose response is an object with one array property and a
  `nextLink`/`next`/`@odata.nextLink` string, or that declare a `Link` response header, get `-All`. `-All`
  follows the next links (relative or absolute, same host only, never the same URL twice) and streams items as
  pages arrive, so `Select-Object -First 5` stops fetching. Without `-All` you get one page. Either way the
  output is the items, each typed `<Service>.<ItemSchema>`.
- **Downloads**: operations with a binary response get `-OutFile`, which streams the body to the file and returns
  its `FileInfo`. Without `-OutFile` the body is returned as one `byte[]`.
- **JSON** responses become objects (no schema validation, no value rewriting) with the PSTypeName
  `<Service>.<Schema>` when the schema is named; text and XML responses are strings; 204/empty responses return
  nothing.
- `-Raw` returns `{ StatusCode, Headers, Content }` instead.

## Errors, retry and logging

- A non-2xx response is written as a non-terminating error through the calling command, so `-ErrorAction`,
  `-ErrorVariable`, `try/catch` with `-ErrorAction Stop` and pipelines behave as for any cmdlet. The error id is
  `OpenApi.<Service>.<StatusCode>` (`OpenApi.<Service>.Connection` for network failures,
  `.Authentication` for TLS/authentication failures, `.NoContext` when there is no connection, `.InvalidArgument`
  and `.OutFile` for local problems). The category is mapped from the status (404 ObjectNotFound, 401
  AuthenticationError, 403 PermissionDenied, 429 LimitsExceeded, ...) and `TargetObject` holds `Method`, `Uri`,
  `StatusCode`, `Headers`, `Body` (parsed problem+json or JSON when possible) and `OperationId`. The message uses the
  problem+json `title` and `detail` when present.
- Retries use tcs.core `Invoke-WithRetry`: 408, 429, 500, 502, 503 and 504 for idempotent methods, 429 and 503
  only for POST and PATCH, honouring `Retry-After`; `-MaxRetries` on the context (default 3).
- `-Verbose` shows each request line, status and timing; `-Debug` adds headers and bodies with secrets redacted.
- A deprecated operation writes one warning per session.

## Naming

1. `x-ps-name` (a full `Verb-Noun`) wins; otherwise `x-ps-verb` and `x-ps-noun` replace the derived parts.
2. From the operationId: the first word maps to an approved verb (get/list/find/search -> Get, create/add/new/post
   -> New, update/patch/set/put/replace -> Set for PUT and Update for PATCH, delete/remove -> Remove, and start,
   stop, enable, import, export, test, invoke, send, sync, publish, ... to the matching verb); the rest is the
   noun. Without an operationId: the method's default verb and the last literal path segment.
3. Noun = `<NounPrefix>` + PascalCase words, last word singular, letters and digits only.
4. Collisions add the distinguishing path segment (`Get-PetOwnerByName`) or the method, then a number; each rename
   is finding OA040. The order is deterministic (path, then method), so adding operations does not rename others.
5. A name that equals a core PowerShell command (Microsoft.PowerShell.Core, .Management, .Utility and .Security,
   including the Windows-only ones) is never generated: it gets the PascalCase module name as prefix
   (`Get-Item` -> `Get-ModernItem`), then the collision rules, with finding OA042.
6. Parameters are the PascalCase spec names with the spec name as an alias; names that clash with common
   parameters or the wrapper's own (`All`, `Raw`, `OutFile`, `Body`, `ContentType`) get the location as a suffix
   (`DebugQuery`, OA041).

**Set `-NounPrefix`.** It defaults to nothing, so without it the nouns come straight from the document
(`getItem` -> `Get-Item`) and easily clash with other modules. The connection commands use the prefix too
(`Set-<NounPrefix>Context`, or the PascalCase module name without one).

Vendor extensions read by the generator: `x-ps-name`, `x-ps-verb`, `x-ps-noun` (operation) and `x-ms-pageable`
(paging).

## Supported features

| Area | Supported | Not supported / limits |
|---|---|---|
| Document versions | Swagger 2.0 (converted to the OpenAPI 3 model), OpenAPI 3.0.x and 3.1.x; JSON; YAML with powershell-yaml; from a file, URL or string | Other versions (OA001) |
| `$ref` | Local refs to schemas, parameters, request bodies, responses, headers and security schemes; circular schemas (OA022) | External / URL refs (OA020: the operation is skipped); unresolved refs (OA021) |
| Schemas | allOf merged; `nullable` and 3.1 `["x","null"]`; enum, pattern, minimum/maximum, length and item counts become validation attributes | oneOf/anyOf bodies only as `-Body` (OA050); 3.1 multiple non-null types are untyped (OA031); responses are not validated |
| Parameters | path (simple, label, matrix), query (form, spaceDelimited, pipeDelimited, deepObject, allowReserved), header, cookie; Swagger `collectionFormat` | A `content`-based parameter uses the schema of its first media type and is sent as a plain value |
| Request bodies | JSON (flattened into parameters, or `-Body`), form-urlencoded, multipart (FileInfo values become file parts), binary (byte[], Stream, FileInfo), text | XML and other media types are sent as a raw string or bytes (OA051) |
| Responses | JSON to typed objects, text, binary to byte[] or `-OutFile`, `-Raw` | XML is returned as text |
| Security | apiKey (header, query, cookie), http basic and bearer, oauth2 clientCredentials, any oauth2/openIdConnect scheme with `-BearerToken` | Other oauth2 flows, openIdConnect discovery, mutualTLS, http digest (OA030): use `-BearerToken` or `-Header` |
| Paging | `x-ms-pageable`, nextLink-style properties, `Link: rel="next"` | Offset or cursor paging that needs a request parameter changed |
| Servers | First absolute http(s) server (variables take their defaults) is the `-BaseUri` default | Relative servers are not used as defaults: pass `-BaseUri` |
| Other | Deprecated operations (OA060), missing operationIds (generated, OA010) | Callbacks, links and webhooks are ignored; operations with a duplicate operationId are skipped (OA011, OA070): call them with `Invoke-OpenApiRequest` |

`Test-OpenApiDocument` lists every finding; the codes are listed in [DESIGN.md](DESIGN.md#findings-codes-non-exhaustive).

## PowerShell 5.1 and 7

The generator, the runtime and the generated code avoid PowerShell 7-only syntax and .NET Core-only APIs. The
engine sends requests with one `System.Net.Http.HttpClient` per service on both editions, so behaviour is the same.
`-SkipCertificateCheck` on 5.1 needs .NET Framework 4.7.1 or later
(`HttpClientHandler.ServerCertificateCustomValidationCallback`). Generated modules declare
`CompatiblePSEditions = Desktop, Core` and `PowerShellVersion = 5.1`.

## Security notes

- Secrets are only accepted as `SecureString`/`PSCredential` and are decoded only while a request is built.
- `-Persist` stores secrets with tcs.core `Set-ModuleSecret` (module `tcs.openapi`, name `<service>.<kind>`) and the
  other settings as JSON under the tcs config folder (`TCS_CONFIG_ROOT`); `Remove-<Prefix>Context -Persisted`
  deletes both. A later session loads them on first use.
- `Get-<Prefix>Context` shows every secret as `********`. Debug output redacts `Authorization`, cookies, api-key
  headers and query values, and JSON properties named like password, secret, token, apiKey or client_secret.
- Next-page links are followed only to the same scheme, host and port as the first request.
- `-SkipCertificateCheck` disables TLS validation for that service; use it only for test systems.
- Generated code is plain PowerShell you can review; nothing from the document is evaluated as code.

## Development

```powershell
./Build.ps1 -Task Test             # manifest, PSScriptAnalyzer, Pester (unit, snapshot and end-to-end tests)
./Build.ps1 -Task UpdateSnapshots  # regenerate tests/Snapshots after a deliberate generator change
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CHANGELOG.md](CHANGELOG.md).
