# tcs.openapi design

tcs.openapi turns an OpenAPI 3.0/3.1 or Swagger 2.0 document into a PowerShell module. It has two halves:

- **Generator** (design time): reads a document, normalises it, reports problems and writes a module of thin wrapper functions.
- **Runtime** (call time): one request engine that every generated module uses (auth, serialisation, bodies, retry, paging, errors, downloads). Generated modules declare `RequiredModules = @('tcs.openapi')`, so fixes to the engine reach every generated module without regenerating.

Targets: Windows PowerShell 5.1 and PowerShell 7 (Windows, Linux, macOS) for both halves. Depends on tcs.core 0.4.0 (`Invoke-WithRetry`, `Get-HttpErrorDetail`, `Set/Get/Remove-ModuleSecret`, `Start-TcsTelemetry`/`Invoke-TcsCommand`/`Complete-TcsTelemetry`, `ConvertTo-PascalCase`).

Rules for all code: no PS7-only syntax (`??`, `?:`, `&&`, `||`, ternary, `-Parallel`, 3-arg `Join-Path`); no .NET Core-only APIs without a 5.1 fallback; no PowerShell classes (they reload badly on 5.1) - use `[pscustomobject]` with a `PSTypeName`; no `$script:` state shared between generator stages (pass objects); non-ASCII files are UTF-8 with BOM.

## Layout

```
modules/tcs.openapi/
  tcs.openapi.psd1 / .psm1
  Public/            exported commands (one per file)
  Private/Document/  loading, Swagger 2.0 conversion, $ref resolution, normalisation, validation
  Private/Generator/ naming, parameter model, rendering, plan, writing
  Private/Runtime/   context store, auth, serialisation, bodies, paging, errors
  Templates/         generated-module templates (*.template)
  en-GB/ en-US/      about_tcs.openapi.help.txt (identical)
tests/               Module.Tests.ps1, Fixtures/*.json|yaml, Helpers/TestHttpServer.ps1, end-to-end tests
```

Each `Public/*.ps1` and `Private/**/*.ps1` has a sibling `Tests/<name>.Tests.ps1`.

## Public commands

| Command | Half | Purpose |
|---|---|---|
| `Import-OpenApiDocument -Path <file> \| -Uri <url> \| -InputObject <string>` | Generator | Returns the normalised **document model** (below). JSON always; YAML when `ConvertFrom-Yaml` (powershell-yaml) is available, otherwise a clear error. |
| `Test-OpenApiDocument -Path/-Uri/-InputObject \| -Document <model>` | Generator | Returns **findings** `{ Severity (Error/Warning/Information), Code, Pointer (JSON pointer), Message, Operation }` for invalid structure and for features the generator/runtime do not support. Never throws for document problems. |
| `New-OpenApiModule -Path/-Uri/-Document -ModuleName <name> -OutputPath <dir> [-NounPrefix] [-ModuleVersion] [-Author] [-Force] [-WhatIf]` | Generator | Writes a complete module (below). Returns a result object `{ ModuleName, Path, ManifestPath, Functions (name, operationId, file, action), Findings, Skipped }`. Supports ShouldProcess; `-WhatIf` writes nothing. Existing generated files are replaced only with `-Force`; `Overrides.ps1` is never overwritten. |
| `Set-OpenApiContext -Service <name> -BaseUri [-ApiKey <SecureString>] [-Credential <PSCredential>] [-BearerToken <SecureString>] [-ClientId -ClientSecret <SecureString> -TokenUri [-Scope]] [-Header <hashtable>] [-TimeoutSec] [-Proxy] [-ProxyCredential] [-SkipCertificateCheck] [-MaxRetries] [-Persist] [-PassThru]` | Runtime | Stores the connection for a service in module scope. `-Persist` saves secrets with `Set-ModuleSecret -ModuleName tcs.openapi -Name <service>.<kind>` and settings as JSON; a later session loads them lazily. |
| `Get-OpenApiContext [-Service]` | Runtime | Returns contexts with every secret shown as `********`. |
| `Remove-OpenApiContext -Service [-Persisted]` | Runtime | Clears the context (and saved secrets with `-Persisted`). |
| `Invoke-OpenApiRequest -Service <name> -Operation <operation metadata> [-PathParameters] [-QueryParameters] [-HeaderParameters] [-CookieParameters] [-Body] [-ContentType] [-OutFile] [-All] [-Raw] [-Cmdlet <PSCmdlet>]` | Runtime | The engine. Generated wrappers call it; users can call it directly for operations the generator skipped. |

`Test-OpenApiDocument`, `Import-OpenApiDocument` and `New-OpenApiModule` use the tcs.core telemetry wrapper like every other tcs module.

## Document model (output of Import-OpenApiDocument)

Always OpenAPI 3-shaped, whatever the input version. `PSTypeName = 'Tcs.OpenApi.Document'`.

```
{
  SourceVersion : '2.0' | '3.0.x' | '3.1.x'
  Title, Version, Description
  Servers       : [ { Url, Description, Variables: { name: { Default, Enum } } } ]   # Swagger 2: from schemes/host/basePath
  SecuritySchemes: { name: SecurityScheme }
  Security      : [ { schemeName: [scopes] } ]                                      # document default
  Schemas       : { name: <schema, $ref-free where possible> }                      # components/schemas or definitions
  Operations    : [ Operation ]
  Findings      : [ finding ]                                                        # problems met while normalising
}

SecurityScheme { Name, Type ('apiKey'|'http'|'oauth2'|'openIdConnect'), In ('header'|'query'|'cookie'), ParameterName, Scheme ('basic'|'bearer'|...), BearerFormat, Flows: { clientCredentials: { TokenUrl, Scopes } , ... } }

Operation {
  PSTypeName  : 'Tcs.OpenApi.Operation'
  OperationId : string (spec value, or generated '<method><PathPascal>' and a finding when missing)
  Method      : 'GET'|'PUT'|'POST'|'DELETE'|'OPTIONS'|'HEAD'|'PATCH'|'TRACE' (upper case)
  Path        : '/pets/{petId}'
  Tags        : [string]
  Summary, Description, Deprecated (bool), ExternalDocsUrl
  Parameters  : [ Parameter ]          # path-level merged in; operation-level wins on (Name, In)
  RequestBody : null | { Required (bool), Description, Content: [ MediaType ] }
  Responses   : [ { StatusCode ('200'|'2XX'|'default'...), Description, Content: [ MediaType ], Headers } ]
  Security    : null (use document default) | [] (no auth) | [ { schemeName: [scopes] } ]
  Paging      : null | { Kind ('nextLink'|'linkHeader'), ItemsProperty, NextLinkProperty }   # from x-ms-pageable, or detected: response object with one array property + a 'nextLink'/'next'/'@odata.nextLink' string
  Extensions  : { 'x-...': value }     # includes x-ps-name, x-ps-noun, x-ps-verb overrides
}

Parameter { Name (spec), In ('path'|'query'|'header'|'cookie'), Required, Description, Deprecated, Schema, Style, Explode, AllowReserved, Example }
  # defaults per spec: path/header -> simple, query/cookie -> form; explode true for form, false otherwise
  # Swagger 2.0 collectionFormat maps: csv->form/explode false, ssv->spaceDelimited, pipes->pipeDelimited, multi->form/explode true

MediaType { ContentType, Schema, Encoding }     # ordered: JSON types first (application/json, then */*+json)

Schema (normalised, OAS 3.0 vocabulary):
  { Type ('string'|'integer'|'number'|'boolean'|'array'|'object'|null), Format, Nullable (bool), Enum, Default, Const,
    Items, Properties { name: Schema }, Required [..], AdditionalProperties (bool|Schema),
    AllOf/OneOf/AnyOf [Schema], Discriminator, ReadOnly, WriteOnly, Description, RefName (schema name when it came from a $ref), Recursive (bool) }
  # 3.1 type arrays: ['string','null'] -> Type 'string' + Nullable true; multiple non-null types -> Type null + finding
  # allOf is merged into Properties/Required (keeping AllOf for reference); circular $ref -> Recursive = true, not expanded again
```

`$ref` handling: local refs (`#/components/...`, `#/definitions/...`) for schemas, parameters, requestBodies, responses, headers, securitySchemes are resolved; external/URL refs produce an Error finding and the affected operation is flagged `Unsupported`. Resolution uses a visited set, so circular schemas never recurse forever.

## Operation metadata (what the generator embeds and the runtime consumes)

The generated module writes `OpenApi/operations.json` and loads it once into `$script:TcsOpenApiOperations` (a hashtable keyed by operationId). Each entry is the minimal runtime view of an Operation, `PSTypeName = 'Tcs.OpenApi.OperationMetadata'`:

```
{ OperationId, Method, Path, Service, Deprecated,
  Parameters : [ { Name, In, Style, Explode, AllowReserved } ],   # spec names; wrappers pass values keyed by spec name
  RequestContentTypes : [string], ResponseContentTypes : [string], BinaryResponse (bool),
  Security : null | [] | [ { scheme: [scopes] } ], SecuritySchemes : { name: SecurityScheme },  # copy of the relevant schemes
  Paging : null | { ... }, ResponseTypeName : 'Service.SchemaName' | null }
```

## Runtime behaviour (Invoke-OpenApiRequest)

- **URL**: context `BaseUri` + path; path values escaped per segment (`[uri]::EscapeDataString`), `allowReserved` honoured for query.
- **Query/header/cookie serialisation**: only parameters present in the passed hashtables are sent (wrappers pass `$PSBoundParameters`-derived values only). Arrays and objects follow style/explode (`form`, `spaceDelimited`, `pipeDelimited`, `deepObject`); booleans as `true`/`false`; `[datetime]` as ISO 8601 round-trip (`o`); cookies as one `Cookie` header.
- **Bodies**: by content type - JSON (`ConvertTo-Json -Depth 64 -Compress`, `charset=utf-8`), `application/x-www-form-urlencoded` (hashtable -> encoded pairs), `multipart/form-data` (hashtable; `[System.IO.FileInfo]`/path-with-`-AsFile` values become file parts; built with `System.Net.Http.MultipartFormDataContent` on both editions), `application/octet-stream`/other binary (`[byte[]]`, `[IO.Stream]` or `[IO.FileInfo]`), `text/*` (string). Explicit `$null` values are sent as JSON null.
- **Auth**: the operation's `Security` (or the document default) picks the first requirement whose schemes all have credentials in the context. apiKey header/query/cookie; http basic (`Credential`); http bearer (`BearerToken`); oauth2 clientCredentials (fetch token from `TokenUri`, cache until 60 s before expiry, refresh on 401 once). `Security = []` sends no credentials. Secrets are held as `SecureString` and decoded only when building the request.
- **Transport**: `HttpClient` shared per service (created lazily, disposed on module removal) so behaviour is identical on 5.1 and 7; timeout, proxy, SkipCertificateCheck (PS7 via handler callback; 5.1 via `ServerCertificateCustomValidationCallback` on `HttpClientHandler` where available, otherwise a clear error).
- **Retry**: `Invoke-WithRetry` from tcs.core with `-RetryOnStatusCode 408,429,500,502,503,504` for idempotent methods and 429/503 only for POST/PATCH; honours `Retry-After`; `MaxRetries` from context (default 3).
- **Responses**: JSON -> `ConvertFrom-Json` objects (no schema validation, no value rewriting) with `PSTypeName` = `ResponseTypeName` added to each object (array items individually); `-Raw` returns `{ StatusCode, Headers, Content (string|byte[]) }`; binary or `-OutFile` streams to the file and returns the `FileInfo`; 204/empty -> nothing.
- **Paging**: with `-All`, follow `nextLink` (same host only) or the `Link: rel="next"` header, emitting items as they arrive; without `-All`, one page.
- **Errors**: non-2xx -> `ErrorRecord` with `FullyQualifiedErrorId = 'OpenApi.<Service>.<StatusCode>'` (network failures `OpenApi.<Service>.Connection`), category mapped from status, `TargetObject = { Method, Uri, StatusCode, Headers, Body (parsed problem+json when possible), OperationId }`, message from problem+json `title`/`detail` or the status text. Written with `$Cmdlet.WriteError()` when `-Cmdlet` is passed (so `-ErrorAction` and pipelines behave), otherwise `Write-Error`.
- **Verbose/Debug**: request line and status always in Verbose; headers and bodies only in Debug, with `Authorization`, api-key headers/query values, cookies and JSON properties named like `password|secret|token|apiKey|client_secret` replaced by `********`.
- **Deprecated** operations write one warning per session.

## Generated module

```
<OutputPath>/<ModuleName>/
  <ModuleName>.psd1        RequiredModules tcs.openapi (min version = generator version); FunctionsToExport listed explicitly
  <ModuleName>.psm1        loads OpenApi/operations.json, dot-sources Public/**/*.ps1 then Overrides.ps1; sets Service name
  OpenApi/operations.json  operation metadata (above)
  OpenApi/source.json      the normalised document (for regeneration diffs)
  Public/<Tag>/<Verb>-<Noun>.ps1   one wrapper per operation; untagged -> Public/Default
  Overrides.ps1            created once, never overwritten; functions defined here replace generated ones of the same name
  Connect-<Prefix>.ps1 ... (inside Public/_Connection) thin Set-/Get-/Remove-<Prefix>Context wrappers calling the runtime with -Service fixed
  README.md                generated command list
```

### Naming
1. `x-ps-name` (full `Verb-Noun`) wins; else `x-ps-verb`/`x-ps-noun`.
2. From operationId: split camelCase/PascalCase/snake/kebab into words; if the first word maps to a verb (get/list/find/search -> Get (list/search/find -> Get with plural->singular noun + note), create/add/new/post -> New, update/patch/set/put/replace -> Set for PUT, Update for PATCH, delete/remove -> Remove, start/stop/restart/enable/disable/approve/deny/import/export/test/invoke/send/reset/clear/copy/move/rename/sync/publish/register/unregister/connect/disconnect -> matching approved verb; unknown -> method default), the rest is the noun.
3. No operationId: method default verb (GET Get, POST New, PUT Set, PATCH Update, DELETE Remove, HEAD/OPTIONS Test/Get) + noun from the last non-parameter path segments.
4. Noun = `<NounPrefix>` + PascalCase words, singularised last word (simple English rules, list of irregulars), only `[A-Za-z0-9]`.
5. Collisions: add the distinguishing path segment or method as a word (`Get-PetOwner` vs `Get-PetOwnerByName`), never a hash; last resort a number suffix; every rename is a Warning finding. Order is deterministic (sorted by path, then method), so adding operations never renames existing ones unless they collide.
6. Verbs are always approved (`Get-Verb`).

### Parameters
- PowerShell name = PascalCase of the spec name (`X-Request-Id` -> `XRequestId`, `user_id` -> `UserId`); the spec name is kept in metadata. Clashes with common parameters (`Verbose`, `Debug`, `ErrorAction`, `WarningAction`, `InformationAction`, `ErrorVariable`, `WarningVariable`, `InformationVariable`, `OutVariable`, `OutBuffer`, `PipelineVariable`, `WhatIf`, `Confirm`, `ProgressAction`) or the wrapper's own switches (`All`, `Raw`, `OutFile`, `Body`, `ContentType`) get a suffix from `In` (`DebugQuery`); two spec parameters mapping to one name get suffixes too; each is a Warning finding.
- Types: string -> `[string]` (`format: date-time` -> `[datetime]`, `binary` -> `[object]` accepting byte[]/FileInfo/path), integer -> `[int]`/`[long]` (int64 or unbounded), number -> `[double]`, boolean -> `[switch]` for optional query/header booleans and `[bool]` for required ones, array -> element type `[]`, object -> `[hashtable]`; nullable adds `[AllowNull()]`.
- `Mandatory` only for required path/query/header/cookie parameters and top-level required body properties when the body itself is required.
- Enums -> `[ValidateSet(...)]` (array items too); `ValidatePattern`/`ValidateRange`/`ValidateLength` from pattern/minimum/maximum/minLength/maxLength.
- Every parameter `ValueFromPipelineByPropertyName`; aliases: the spec name when different from the PS name, and `Id` for a path parameter named `<noun>Id`.
- Body: JSON object bodies are flattened into parameters (one per top-level property, readOnly omitted; nested objects as `[hashtable]`) **and** a `-Body` parameter (`[object]`, separate parameter set) for passing the whole body; other body shapes get only `-Body` with a type matching the media type (`[object]` for arrays/primitives/oneOf, `[hashtable]` for form/multipart, `[object]` for binary). No defaults are injected.
- Every wrapper also has `-Raw` and, when the operation is pageable, `-All`; when a response is binary, `-OutFile`.
- `SupportsShouldProcess` for every method except GET/HEAD/OPTIONS; `ConfirmImpact = 'High'` for DELETE, `'Medium'` otherwise.

### Wrapper shape (rendered from `Templates/Function.ps1.template`)
Comment-based help (summary -> SYNOPSIS, description -> DESCRIPTION, parameter descriptions, one runnable EXAMPLE built from required parameters, `.LINK` to externalDocs, deprecation note), `[CmdletBinding(...)]`, `[OutputType('<Service>.<Schema>')]` when known, `param()`, `process {}` that: builds the four parameter hashtables and the body from `$PSBoundParameters` using a small generated name map, calls `ShouldProcess` when needed, then `Invoke-OpenApiRequest -Service $script:TcsOpenApiService -Operation $script:TcsOpenApiOperations['<id>'] ... -Cmdlet $PSCmdlet`. Generated code must parse, and every function must bind (`Get-Command -Syntax`) - the generator checks both before writing.

## Findings codes (non-exhaustive)
`OA001` invalid/unsupported document version, `OA002` missing paths, `OA010` missing operationId (generated), `OA011` duplicate operationId, `OA020` external $ref, `OA021` unresolved $ref, `OA022` circular schema (information), `OA030` unsupported security scheme type (openIdConnect, oauth2 flows other than clientCredentials), `OA031` multiple non-null types (3.1), `OA040` renamed command (collision), `OA041` renamed parameter (reserved/duplicate), `OA050` oneOf/anyOf body (passed through as -Body only), `OA051` unsupported media type (sent as raw string/bytes), `OA060` deprecated operation, `OA070` operation skipped.

## Testing
- Unit tests per function (pure functions take/return objects, no disk).
- Fixtures: petstore-like 3.0, 3.1, Swagger 2.0, circular, external-ref, reserved names, auth variants, bodies (json/form/multipart/binary/array), paging (nextLink + Link header).
- Snapshot tests: generated module for 3 fixtures compared with checked-in expected output (`tests/Snapshots/`), regenerated with `Build.ps1 -Task UpdateSnapshots`.
- End-to-end: `tests/Helpers/TestHttpServer.ps1` starts an `HttpListener` on 127.0.0.1 with a free port in a background runspace, records requests and serves scripted responses; generated modules are imported and called against it (auth, serialisation, bodies, paging, retry on 429 with Retry-After, errors, downloads).
- PSScriptAnalyzer clean with repo settings; bind check on every generated function.
