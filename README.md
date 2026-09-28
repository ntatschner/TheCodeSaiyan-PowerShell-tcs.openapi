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
Install-Module tcs.openapi -Scope CurrentUser   # also installs its RequiredModule tcs.core (0.4.1 or later)
```

Requirements: Windows PowerShell 5.1 or PowerShell 7 (Windows, Linux, macOS) and tcs.core 0.4.1. YAML
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

### Envelopes: -UnwrapProperty

Some APIs wrap every result, for example `{ "data": { ... }, "httpStatusCode": 200, "traceId": "..." }`.
`New-OpenApiModule -UnwrapProperty data` makes each command whose first 2xx JSON response schema is an object
with a `data` property return the value of `data` instead (an array item by item), typed with that property's
schema name when it has one. It applies only when a response actually has the property, never with `-Raw`, and
not to pageable operations, which return the items of each page anyway.

```powershell
New-OpenApiModule -Path ./sitemanager.json -ModuleName UniFi.SiteManager -NounPrefix UniFi -UnwrapProperty data -OutputPath ./out
Get-UniFiHostById -Id $id        # the host, not { data, httpStatusCode, traceId }
Get-UniFiHost -All               # every host, following nextToken
Get-UniFiConnector -Id $id -Path 'proxy/network/integration/v1/sites'
```

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
built from the document, `[CmdletBinding()]`, `-WhatIf`/`-Confirm` for the commands that change data (see below),
and `-Raw`; pageable operations get `-All` and binary responses `-OutFile`.
JSON object bodies are flattened into one parameter per writable top-level property (nested objects as
`[hashtable]`), with `-Body` as an alternative parameter set for the whole body.

### -WhatIf and -Confirm

A generated command gets `-WhatIf` and `-Confirm` when it can change data:

- every DELETE (`ConfirmImpact = 'High'`);
- every POST, PUT and PATCH (`ConfirmImpact = 'Medium'`), except `Get-` and `Test-` commands: an operationId
  that starts with get, list, find, search or query (`Get-`), or validate, check or verify (`Test-`), is a read
  that some APIs send as a POST with a body, such as `POST /v1/isp-metrics/{type}/query` (`Get-UniFiIspMetricQuery`);
- any command whose verb changes state (`New`, `Set`, `Remove`, `Start`, `Stop`, `Restart`, `Reset`, `Update`),
  whatever its method.

GET, HEAD and OPTIONS commands with any other verb have neither. A read therefore still runs under
`$WhatIfPreference = $true`, and PSScriptAnalyzer's `PSUseShouldProcessForStateChangingFunctions` rule is met. Use
`x-ps-verb` or `x-ps-name` in the document to change the verb of an operation.

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

## Catch-all paths

Path values are escaped as one segment, so `-Id 'a/b'` is sent as `a%2Fb`. Router-style documents end some paths
with a catch-all segment, such as `/v1/connector/consoles/{id}/*path`. The generator reads a final `*name` (or
`{name*}`) whose name is a path parameter as that parameter, flagged `CatchAll`: its value keeps its slashes and
each segment is escaped on its own, so `-Path 'proxy/network/integration/v1/sites'` calls
`/v1/connector/consoles/<id>/proxy/network/integration/v1/sites` (leading and trailing slashes are dropped).
`allowReserved` path parameters are sent the same way. `Test-OpenApiDocument` reports a path parameter that is
not in the path (OA023, Warning) and a `{placeholder}` without a path parameter (OA024, Error).

## Connections and authentication

`Set-<Prefix>Context` is `Set-OpenApiContext -Service <ModuleName>`: the service name is the module name (the
generated README shows it with the credential parameters of the document's security schemes). It
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

- **Paging**: pageable operations get `-All`, which streams items as pages arrive, so `Select-Object -First 5`
  stops fetching. Without `-All` you get one page. Either way the output is the items, each typed
  `<Service>.<ItemSchema>`. Three kinds are detected (in this order):

  | Kind | Detected from | `-All` |
  |---|---|---|
  | `nextLink` | `x-ms-pageable`, or a response object with one array property and a `nextLink`/`next`/`@odata.nextLink` string | follows the link (relative or absolute, same host only, never the same URL twice) |
  | `token` | a query parameter `nextToken`, `pageToken`, `next_token`, `page_token`, `cursor`, `continuationToken` or `continuation_token` (any case) and a response object with one array property and a string named like the parameter or `nextToken`/`nextPageToken`/`next_page_token`/`next_cursor`/`nextCursor` | repeats the request (same method, body and query parameters) with the token from each response until it is empty, missing or repeats |
  | `linkHeader` | a declared `Link` response header | follows `Link: <...>; rel="next"` |
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
   noun. A last word that repeats the operation's HTTP method is dropped (`ConnectorGet` -> `Get-Connector`,
   `ConnectorPost` -> `New-Connector`, `ConnectorPut` -> `Set-Connector`, `ConnectorPatch` -> `Update-Connector`,
   `ConnectorDelete` -> `Remove-Connector`). Without an operationId: the method's default verb and the last
   literal path segment.
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
| Parameters | path (simple, label, matrix; a final catch-all segment such as `/consoles/{id}/*path` or `{path*}` keeps the slashes of its value), query (form, spaceDelimited, pipeDelimited, deepObject, allowReserved), header, cookie; Swagger `collectionFormat` | A `content`-based parameter uses the schema of its first media type and is sent as a plain value; a path parameter missing from the path is ignored (OA023); a `{placeholder}` without a parameter cannot be filled (OA024) |
| Request bodies | JSON (flattened into parameters, or `-Body`), form-urlencoded, multipart (FileInfo values become file parts), binary (byte[], Stream, FileInfo), text | XML and other media types are sent as a raw string or bytes (OA051) |
| Responses | JSON to typed objects, text, binary to byte[] or `-OutFile`, `-Raw` | XML is returned as text |
| Security | apiKey (header, query, cookie), http basic and bearer, oauth2 clientCredentials, any oauth2/openIdConnect scheme with `-BearerToken` | Other oauth2 flows, openIdConnect discovery, mutualTLS, http digest (OA030): use `-BearerToken` or `-Header` |
| Paging | `x-ms-pageable`, nextLink-style properties, page tokens/cursors returned in the response (`nextToken`, `pageToken`, `cursor`, ...), `Link: rel="next"` | Offset/page-number paging (`offset`, `page`): call again with the next value |
| Responses in an envelope | `-UnwrapProperty` returns one property (such as `data`) of every response that has it | One property name per module |
| Servers | First absolute http(s) server (variables take their defaults) is the `-BaseUri` default | Relative servers are not used as defaults: pass `-BaseUri` |
| Other | Deprecated operations (OA060), missing operationIds (generated, OA010) | Callbacks, links and webhooks are ignored; operations with a duplicate operationId are skipped (OA011, OA070): call them with `Invoke-OpenApiRequest` |

`Test-OpenApiDocument` lists every finding; the codes are listed in [DESIGN.md](DESIGN.md#findings-codes-non-exhaustive).
A document without findings returns nothing and prints `No problems found in <file> (<n> operations).`;
`-Summary` returns one object with the operation count and the number of errors, warnings and information findings.

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
