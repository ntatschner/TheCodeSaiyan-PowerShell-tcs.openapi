# tcs.openapi design

tcs.openapi turns an OpenAPI 3.0/3.1 or Swagger 2.0 document into a PowerShell module. It has two halves:

- **Generator** (design time): reads a document, normalises it, reports problems and writes a module of thin wrapper functions.
- **Runtime** (call time): one request engine that every generated module uses (auth, serialisation, bodies, retry, paging, errors, downloads). Generated modules declare `RequiredModules = @('tcs.openapi')`, so fixes to the engine reach every generated module without regenerating.

Targets: Windows PowerShell 5.1 and PowerShell 7 (Windows, Linux, macOS) for both halves. Depends on tcs.core 0.4.1 (`Invoke-WithRetry`, `Get-HttpErrorDetail`, `Set/Get/Remove-ModuleSecret`, `Start-TcsTelemetry`/`Complete-TcsTelemetry`, `ConvertTo-PascalCase`).

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
tests/               Module.Tests.ps1 (repository guards), Runtime.*.Tests.ps1, Generator.*.Tests.ps1,
                     EndToEnd.*.Tests.ps1, Snapshots/, Fixtures/*.json|yaml,
                     Helpers/ (TestHttpServer.ps1, EndToEnd.ps1, New-TestOpenApiModel.ps1, Update-Snapshots.ps1)
```

Each `Public/*.ps1` and `Private/**/*.ps1` defines one function named like the file and has a sibling
`Tests/<name>.Tests.ps1`; every function (public and private) uses an approved verb. `tests/Module.Tests.ps1`
enforces this, the exports and the help.

## Public commands

| Command | Half | Purpose |
|---|---|---|
| `Import-OpenApiDocument -Path <file> \| -Uri <url> \| -InputObject <string>` | Generator | Returns the normalised **document model** (below). JSON always; YAML when `ConvertFrom-Yaml` (powershell-yaml) is available, otherwise a clear error. |
| `Test-OpenApiDocument -Path/-Uri/-InputObject \| -Document <model>` | Generator | Returns **findings** `{ Severity (Error/Warning/Information), Code, Pointer (JSON pointer), Message, Operation }` for invalid structure and for features the generator/runtime do not support. Never throws for document problems. |
| `New-OpenApiModule -Path/-Uri/-Document -ModuleName <name> -OutputPath <dir> [-NounPrefix] [-UnwrapProperty <name>] [-ModuleVersion] [-Author] [-Force] [-WhatIf]` | Generator | Writes a complete module (below). `-UnwrapProperty` (e.g. `data`) makes the commands output that property of the response instead of the whole response (see Operation metadata). Returns a result object `{ ModuleName, Path, ManifestPath, Functions (name, operationId, file, action), Findings (document + generator), Skipped, Files (every file with its action) }`. Supports ShouldProcess; `-WhatIf` writes nothing. Existing generated files are replaced only with `-Force`; `Overrides.ps1` is never overwritten. `-NounPrefix` has no default (documented as "always set it"); `-ModuleVersion` defaults to 0.1.0 and `-Author` to 'tcs.openapi' so output never depends on the machine. |
| `Set-OpenApiContext -Service <name> -BaseUri [-ApiKey <SecureString>] [-Credential <PSCredential>] [-BearerToken <SecureString>] [-ClientId -ClientSecret <SecureString> -TokenUri [-Scope]] [-Header <hashtable>] [-TimeoutSec] [-Proxy] [-ProxyCredential] [-SkipCertificateCheck] [-MaxRetries] [-Persist] [-PassThru]` | Runtime | Stores the connection for a service in module scope. `-Persist` saves secrets with `Set-ModuleSecret -ModuleName tcs.openapi -Name <service>.<kind>` and settings as JSON; a later session loads them lazily. |
| `Get-OpenApiContext [-Service]` | Runtime | Returns contexts with every secret shown as `********`. |
| `Remove-OpenApiContext -Service [-Persisted]` | Runtime | Clears the context (and saved secrets with `-Persisted`). |
| `Invoke-OpenApiRequest -Service <name> -Operation <operation metadata> [-PathParameters] [-QueryParameters] [-HeaderParameters] [-CookieParameters] [-Body] [-ContentType] [-OutFile] [-All] [-Raw] [-Cmdlet <PSCmdlet>]` | Runtime | The engine. Generated wrappers call it; users can call it directly for operations the generator skipped. |

`Test-OpenApiDocument`, `Import-OpenApiDocument` and `New-OpenApiModule` use the tcs.core telemetry wrapper like every other tcs module.

## Document model (output of Import-OpenApiDocument)

Always OpenAPI 3-shaped, whatever the input version. `PSTypeName = 'Tcs.OpenApi.Document'`.

```
{
  SourceVersion : the version string of the document as written ('2.0', '3.0.3', '3.1.0', ...)
  Title, Version, Description
  Servers       : [ { Url, Description, Variables: { name: { Default, Enum } } } ]   # Swagger 2: from schemes/host/basePath
  SecuritySchemes: { name: SecurityScheme }
  Security      : [ { schemeName: [scopes] } ]                                      # document default
  Schemas       : { name: <schema, $ref-free where possible> }                      # components/schemas or definitions
  Operations    : [ Operation ]
  Findings      : [ finding ]                                                        # problems met while normalising
}

SecurityScheme { Name, Type ('apiKey'|'http'|'oauth2'|'openIdConnect'|...), In ('header'|'query'|'cookie'), ParameterName, Scheme ('basic'|'bearer'|...), BearerFormat,
                 Flows: { clientCredentials: { TokenUrl, AuthorizationUrl, RefreshUrl, Scopes }, ... }, OpenIdConnectUrl, Description }
  # Swagger 2.0 oauth2 'application' flow -> clientCredentials

Operation {
  PSTypeName  : 'Tcs.OpenApi.Operation'
  OperationId : string (spec value, or generated '<method><PathPascal>' and a finding when missing)
  Method      : 'GET'|'PUT'|'POST'|'DELETE'|'OPTIONS'|'HEAD'|'PATCH'|'TRACE' (upper case)
  Path        : '/pets/{petId}'          # a final catch-all segment '*name' or '{name*}' that names a path parameter
                                       # is written '{name}' and that parameter gets CatchAll = true
  Tags        : [string]
  Summary, Description, Deprecated (bool), ExternalDocsUrl
  Parameters  : [ Parameter ]          # path-level merged in; operation-level wins on (Name, In)
  RequestBody : null | { Required (bool), Description, Content: [ MediaType ] }
  Responses   : [ { StatusCode ('200'|'2XX'|'default'...), Description, Content: [ MediaType ], Headers } ]
  Security    : null (use document default) | [] (no auth) | [ { schemeName: [scopes] } ]
  Paging      : null | { Kind ('nextLink'|'linkHeader'), ItemsProperty, NextLinkProperty }   # from x-ms-pageable, or detected: response object with one array property + a 'nextLink'/'next'/'@odata.nextLink' string
              |        { Kind 'token', ItemsProperty, TokenParameter, TokenProperty }
                # token: a query parameter named nextToken, pageToken, next_token, page_token, cursor, continuationToken or
                # continuation_token (any case) and a first 2xx JSON response object with exactly one array property and a
                # string property named like the parameter (preferred) or nextToken, nextPageToken, next_page_token,
                # next_token, next_cursor, nextCursor (any case). Order: x-ms-pageable, nextLink, token, linkHeader.
  Extensions  : { 'x-...': value }     # includes x-ps-name, x-ps-noun, x-ps-verb overrides
  Unsupported : bool                   # true when the operation uses an external $ref (OA020); the generator skips it (OA070)
}

Parameter { Name (spec), In ('path'|'query'|'header'|'cookie'), Required, Description, Deprecated, Schema, Style, Explode, AllowReserved, Example, CatchAll }
  # CatchAll: true only for the path parameter of a catch-all segment (its value is a path of its own)
  # defaults per spec: path/header -> simple, query/cookie -> form; explode true for form, false otherwise
  # Swagger 2.0 collectionFormat maps: csv->form/explode false, ssv->spaceDelimited, pipes->pipeDelimited, multi->form/explode true

MediaType { ContentType, Schema, Encoding }     # ordered: JSON types first (application/json, then */*+json)

Schema (normalised, OAS 3.0 vocabulary):
  { Type ('string'|'integer'|'number'|'boolean'|'array'|'object'|null), Format, Nullable (bool), Enum, Default, Const,
    Items, Properties { name: Schema }, Required [..], AdditionalProperties (bool|Schema),
    AllOf/OneOf/AnyOf [Schema], Discriminator, ReadOnly, WriteOnly, Description, RefName (schema name when it came from a $ref), Recursive (bool) }
  # 3.1 type arrays: ['string','null'] -> Type 'string' + Nullable true; multiple non-null types -> Type null + finding
  # allOf is merged into Properties/Required (keeping AllOf for reference); circular $ref -> Recursive = true, not expanded again
  # Inside a named schema, a $ref to another named schema is a *stub*: RefName plus the scalar keywords (Type, Format,
  # Enum, Nullable, bounds ...) and an Items stub, but no Properties/Required/AllOf/OneOf/AnyOf/Discriminator. The full
  # schema is Document.Schemas[RefName] (the generator looks it up with Resolve-OpenApiGenSchema). Stubs keep the
  # model linear in size. Operation-level schemas (parameters, bodies, responses) are resolved one level.
```

`$ref` handling: local refs (`#/components/...`, `#/definitions/...`) for schemas, parameters, requestBodies, responses, headers, securitySchemes are resolved; external/URL refs produce an Error finding and the affected operation is flagged `Unsupported`. Resolution uses a visited set, so circular schemas never recurse forever.

## Operation metadata (what the generator embeds and the runtime consumes)

The generated module writes `OpenApi/operations.json` (sorted by operationId, deterministic JSON) and loads it once with
`ConvertFrom-Json` into `$script:TcsOpenApiOperations` (a case-sensitive hashtable keyed by operationId); each entry is a
`PSCustomObject` with `Tcs.OpenApi.OperationMetadata` inserted as its first type name. The engine reads every member
through `Get-OpenApiMember`, so it accepts these objects as well as hand-built hashtables (for direct
`Invoke-OpenApiRequest` calls). Each entry is the minimal runtime view of an Operation:

```
{ OperationId, Method, Path, Service, Deprecated,
  Parameters : [ { Name, In, Style, Explode, AllowReserved [, CatchAll] } ],   # spec names; wrappers pass values keyed by spec name;
                                                                  # CatchAll written only when true
  RequestContentTypes : [string], ResponseContentTypes : [string], BinaryResponse (bool),
  Security : null | [] | [ { scheme: [scopes] } ], SecuritySchemes : { name: SecurityScheme },  # copy of the relevant schemes
  Paging : null | { Kind, ItemsProperty, NextLinkProperty } | { Kind 'token', ItemsProperty, TokenParameter, TokenProperty },
  ResponseTypeName : 'Service.SchemaName' | null,
  UnwrapProperty : name }            # only with New-OpenApiModule -UnwrapProperty, see below
```

- `Service` is the module name (the connection context of the generated module is `Set-OpenApiContext -Service <ModuleName>`).
- `Security` is resolved at generation time: the operation's own list, else the document default (`Security` of the
  model); `null` only when neither exists. `SecuritySchemes` is a copy of the schemes those requirements name. At call
  time `null` means: a `DefaultSecurity` member when present, else each scheme of `SecuritySchemes` on its own, else
  (no schemes at all) the context's bearer token or credential ("Generic").
- `ResponseTypeName` is `<Service>.<RefName>` of the first 2xx JSON response schema, of its array items, or - for an
  operation whose `Paging.ItemsProperty` names an array of a named schema - of those items, because the engine
  outputs the items of a page.
- `BinaryResponse` is true when a 2xx response has a binary media type/schema.
- `UnwrapProperty` is written for an operation without `Paging` whose first 2xx JSON response schema is an object
  with the property named by `New-OpenApiModule -UnwrapProperty`; `ResponseTypeName` is then the type of that
  property (or of its array items), not of the envelope.
- Backwards compatibility: metadata written by 0.1.x has no `CatchAll`, token `Paging` or `UnwrapProperty`; a
  missing member means the old behaviour (escaped path value, nextLink/Link paging, whole response).

## Runtime behaviour (Invoke-OpenApiRequest)

- **URL**: context `BaseUri` + path; path values escaped per segment (`[uri]::EscapeDataString`), `allowReserved` honoured for query. A scalar value of a `CatchAll` or `AllowReserved` path parameter (simple style) keeps its `/`: it is trimmed of leading/trailing `/`, split on `/`, each segment escaped and re-joined (`-Path 'proxy/network/v1/sites'` -> `/consoles/c1/proxy/network/v1/sites`).
- **Query/header/cookie serialisation**: only parameters present in the passed hashtables are sent (wrappers pass `$PSBoundParameters`-derived values only). Arrays and objects follow style/explode (`form`, `spaceDelimited`, `pipeDelimited`, `deepObject`); booleans as `true`/`false`; `[datetime]` as ISO 8601 round-trip (`o`); cookies as one `Cookie` header.
- **Bodies**: by content type - JSON (`ConvertTo-Json -Depth 64 -Compress`, `charset=utf-8`), `application/x-www-form-urlencoded` (hashtable -> encoded pairs), `multipart/form-data` (hashtable; `[System.IO.FileInfo]`/path-with-`-AsFile` values become file parts; built with `System.Net.Http.MultipartFormDataContent` on both editions), `application/octet-stream`/other binary (`[byte[]]`, `[IO.Stream]` or `[IO.FileInfo]`), `text/*` (string). Explicit `$null` values are sent as JSON null.
- **Auth**: the operation's `Security` (or the document default) picks the first requirement whose schemes all have credentials in the context. apiKey header/query/cookie; http basic (`Credential`); http bearer (`BearerToken`); oauth2 clientCredentials (fetch token from the context `TokenUri`, else the flow's `TokenUrl`; scopes from the context, else the requirement; cache until 60 s before expiry, refresh on 401 once). A context `BearerToken` satisfies any oauth2 or openIdConnect scheme and wins over client credentials. `Security = []` sends no credentials. Secrets are held as `SecureString` and decoded only when building the request.
- **Transport**: `HttpClient` shared per service (created lazily, disposed on module removal) so behaviour is identical on 5.1 and 7; timeout, proxy, SkipCertificateCheck (PS7 via handler callback; 5.1 via `ServerCertificateCustomValidationCallback` on `HttpClientHandler` where available, otherwise a clear error).
- **Retry**: `Invoke-WithRetry` from tcs.core with `-RetryOnStatusCode 408,429,500,502,503,504` for idempotent methods and 429/503 only for POST/PATCH; honours `Retry-After`; `MaxRetries` from context (default 3).
- **Responses**: JSON -> objects via `ConvertFrom-OpenApiResponseJson` (no schema validation, no value rewriting: date strings stay strings) with `PSTypeName` = `ResponseTypeName` added to each object (array items individually); with `UnwrapProperty` (and no paging) the value of that property is output instead of the response object when the parsed response has it (array values item by item), never with `-Raw`; text and XML -> string; `-Raw` returns `{ StatusCode, Headers, Content (string|byte[]) }` (PSTypeName `Tcs.OpenApi.RawResponse`); `-OutFile` streams the body to the file and returns the `FileInfo`; a binary response without `-OutFile` returns the body as one `byte[]`; 204/empty -> nothing.
- **Paging**: a pageable operation always outputs the items of each page (the `ItemsProperty` array), never the page object. With `-All`, follow `nextLink` (relative or absolute, same scheme/host/port only, never a URL twice) or the `Link: rel="next"` header with GET and no body, emitting items as they arrive (stopping the pipeline stops fetching); without `-All`, one page and a Verbose note that more exist. Token paging (`Kind = 'token'`): with `-All` the request is repeated with the same method, body and query parameters plus `TokenParameter` = the response's `TokenProperty`, until the token is empty or missing, or repeats (warning); `-Raw -All` returns every raw page.
- **Errors**: non-2xx -> `ErrorRecord` with `FullyQualifiedErrorId = 'OpenApi.<Service>.<StatusCode>'` (other ids: `OpenApi.<Service>.Connection` for network failures, `.Authentication` for TLS/authentication exceptions, `.NoContext` when the service has no context, `.InvalidArgument` for values that cannot be serialised, `.OutFile` when the file cannot be written, and `OpenApi.MissingService`), category mapped from status, `TargetObject = { Method, Uri, StatusCode, Headers, Body (parsed problem+json when possible), OperationId }`, message from problem+json `title`/`detail` or the status text. Written with `$Cmdlet.WriteError()` when `-Cmdlet` is passed (so `-ErrorAction` and pipelines behave), otherwise `Write-Error`.
- **Preferences**: `-Verbose`, `-Debug` and `-WarningAction` given to the calling (generated) command are read from `$Cmdlet.MyInvocation.BoundParameters` (`$Cmdlet.SessionState` only sees the calling module's script scope); otherwise the preference visible to the calling module applies.
- **Verbose/Debug**: request line and status always in Verbose; headers and bodies only in Debug, with `Authorization`, api-key headers/query values, cookies and JSON properties named like `password|secret|token|apiKey|client_secret` replaced by `********`.
- **Deprecated** operations write one warning per service and operation per session (through `-Cmdlet`, so `-WarningAction` works).
- **Persisted contexts** (`-Persist`): settings as JSON in `<TCS config root>/tcs.openapi/Contexts/<service>.json`, secrets with `Set-ModuleSecret -ModuleName tcs.openapi -Name <service>.<kind>`; loaded on first use when the session has no context for the service.

## Generated module

```
<OutputPath>/<ModuleName>/
  <ModuleName>.psd1        RequiredModules tcs.openapi (min version = generator version); FunctionsToExport listed explicitly
  <ModuleName>.psm1        sets $script:TcsOpenApiService (= ModuleName), loads OpenApi/operations.json, dot-sources Public/**/*.ps1
                           (sorted) then Overrides.ps1; cmdlets are module-qualified because a generated command may share a name
  OpenApi/operations.json  operation metadata (above)
  OpenApi/source.json      the normalised document (compressed, without null/empty values; for regeneration diffs)
  Public/<Tag>/<Verb>-<Noun>.ps1   one wrapper per operation; folder = PascalCase first tag, untagged -> Public/Default
  Public/_Connection/Set-|Get-|Remove-<Prefix>Context.ps1   thin wrappers of Set-/Get-/Remove-OpenApiContext with -Service fixed;
                           <Prefix> = NounPrefix, else the PascalCase module name; -BaseUri of Set- defaults to the first absolute
                           http(s) server URL (server variables replaced by their defaults), else it is mandatory
  Overrides.ps1            created once, never overwritten; functions defined here replace generated ones of the same name
  README.md                generated command list; its "Getting started" shows Set-<Prefix>Context with the credential
                           parameters of the document's security (first document requirement, else the first operation
                           requirement, else the first scheme: apiKey -ApiKey, http basic -Credential, http bearer and
                           other oauth2/openIdConnect -BearerToken, oauth2 clientCredentials -ClientId/-ClientSecret) and
                           -BaseUri only when there is no default server
```

Output is deterministic (same document and options -> byte-identical files: ordinal sorting, LF line endings,
UTF-8 with a BOM only when a file is not ASCII). Operations without an operationId, with a duplicate one, flagged
`Unsupported`, or whose rendered function fails the parse/bind check are skipped with OA070.

### Naming
1. `x-ps-name` (full `Verb-Noun`) wins; else `x-ps-verb`/`x-ps-noun`.
2. From operationId: split camelCase/PascalCase/snake/kebab into words; if the first word maps to a verb (get/list/find/search -> Get (list/search/find -> Get with plural->singular noun + note), create/add/new/post -> New, update/patch/set/put/replace -> Set for PUT, Update for PATCH, delete/remove -> Remove, start/stop/restart/enable/disable/approve/deny/import/export/test/invoke/send/reset/clear/copy/move/rename/sync/publish/register/unregister/connect/disconnect -> matching approved verb; unknown -> method default), the rest is the noun. When the noun then ends with the operation's own HTTP method word (Get, Post, Put, Patch, Delete, Head, Options, Trace) and other words remain, that word is dropped (`ConnectorGet` GET -> `Get-Connector`, `ConnectorPost` POST -> `New-Connector`, `ConnectorPatch` -> `Update-Connector`); a method word that is not the operation's method stays part of the noun (`listProductOptions` -> `Get-ProductOption`).
3. No operationId: method default verb (GET Get, POST New, PUT Set, PATCH Update, DELETE Remove, HEAD/OPTIONS Test/Get) + noun from the last non-parameter path segments.
4. Noun = `<NounPrefix>` + PascalCase words, singularised last word (simple English rules, list of irregulars), only `[A-Za-z0-9]`.
5. Collisions: add the distinguishing path segment or method as a word (`Get-PetOwner` vs `Get-PetOwnerByName`), never a hash; last resort a number suffix; every rename is a Warning finding. Order is deterministic (sorted by path, then method), so adding operations never renames existing ones unless they collide.
6. Verbs are always approved (`Get-Verb`, the list common to 5.1 and 7).
7. A name equal to a command of the core PowerShell modules (Microsoft.PowerShell.Core/Management/Utility/Security, a
   fixed list taken from PowerShell 7.4 plus the Windows-only and 5.1-only commands, so the result does not depend on
   the machine) or to a tcs.openapi command is never generated. Core-command clashes are renamed with the connection
   prefix first (`Get-Item` -> `Get-<ModuleName>Item` when there is no NounPrefix), then the collision rules, as an
   OA042 Warning.

### Parameters
- PowerShell name = PascalCase of the spec name (`X-Request-Id` -> `XRequestId`, `user_id` -> `UserId`); the spec name is kept in metadata. Clashes with common parameters (`Verbose`, `Debug`, `ErrorAction`, `WarningAction`, `InformationAction`, `ErrorVariable`, `WarningVariable`, `InformationVariable`, `OutVariable`, `OutBuffer`, `PipelineVariable`, `WhatIf`, `Confirm`, `ProgressAction`) or the wrapper's own switches (`All`, `Raw`, `OutFile`, `Body`, `ContentType`) get a suffix from `In` (`DebugQuery`); two spec parameters mapping to one name get suffixes too; each is a Warning finding.
- Values reach the engine keyed by spec name; switches are passed as `[bool]` (`.IsPresent`), so `-Flag:$false` sends `false`.
- Types: string -> `[string]` (`format: date-time` -> `[datetime]`, `binary` -> `[object]` accepting byte[]/FileInfo/path), integer -> `[int]`/`[long]` (int64 or unbounded), number -> `[double]`, boolean -> `[switch]` for optional query/header booleans and `[bool]` for required ones, array -> element type `[]`, object -> `[hashtable]`; nullable adds `[AllowNull()]`.
- `Mandatory` only for required path/query/header/cookie parameters and top-level required body properties when the body itself is required.
- Enums -> `[ValidateSet(...)]` (array items too); `ValidatePattern`/`ValidateRange`/`ValidateLength` from pattern/minimum/maximum/minLength/maxLength.
- Every parameter `ValueFromPipelineByPropertyName`; aliases: the spec name when different from the PS name, and `Id` for a path parameter named `<noun>Id`.
- Body: JSON object bodies are flattened into parameters (one per top-level property, readOnly omitted; nested objects as `[hashtable]`) **and** a `-Body` parameter (`[object]`, separate parameter set) for passing the whole body; other body shapes get only `-Body` with a type matching the media type (`[object]` for arrays/primitives/oneOf, `[hashtable]` for form/multipart, `[object]` for binary). No defaults are injected.
- Every wrapper also has `-Raw` and, when the operation is pageable (any paging kind), `-All`; when a response is binary, `-OutFile`.
- `SupportsShouldProcess` for every method except GET/HEAD/OPTIONS; `ConfirmImpact = 'High'` for DELETE, `'Medium'` otherwise.

### Wrapper shape (rendered from `Templates/Function.ps1.template`)
Comment-based help (summary -> SYNOPSIS, description -> DESCRIPTION, parameter descriptions, one runnable EXAMPLE built from required parameters, `.LINK` to externalDocs, deprecation note), `[CmdletBinding(...)]`, `[OutputType('<Service>.<Schema>')]` when known, `param()`, `process {}` that: builds the four parameter hashtables and the body from `$PSBoundParameters` using a small generated name map, calls `ShouldProcess` when needed, then `Invoke-OpenApiRequest -Service $script:TcsOpenApiService -Operation $script:TcsOpenApiOperations['<id>'] ... -Cmdlet $PSCmdlet`. Generated code must parse, and every function must bind (`Get-Command -Syntax`) - the generator checks both before writing.

## Findings codes (non-exhaustive)
`OA001` invalid/unsupported document version, `OA002` missing paths, `OA010` missing operationId (generated), `OA011` duplicate operationId, `OA020` external $ref, `OA021` unresolved $ref, `OA022` circular schema (information), `OA023` path parameter not in the path template (warning; ignored), `OA024` path template placeholder without a path parameter (error), `OA030` unsupported security scheme type (openIdConnect, oauth2 flows other than clientCredentials), `OA031` multiple non-null types (3.1), `OA040` renamed command (collision), `OA041` renamed parameter (reserved/duplicate), `OA042` renamed command (would shadow a core PowerShell command), `OA050` oneOf/anyOf body (passed through as -Body only), `OA051` unsupported media type (sent as raw string/bytes), `OA060` deprecated operation, `OA070` operation skipped.

## Testing
- Unit tests per function (pure functions take/return objects, no disk).
- Fixtures: petstore-like 3.0, 3.1, Swagger 2.0, circular, external-ref, reserved names, auth variants, bodies (json/form/multipart/binary/array), paging (nextLink + Link header), path templates (catch-all, OA023/OA024) and a real-world document (UniFi Site Manager: catch-all paths, token paging, a `data` envelope).
- Snapshot tests: generated module for 3 fixtures compared with checked-in expected output (`tests/Snapshots/`), regenerated with `Build.ps1 -Task UpdateSnapshots`.
- End-to-end (`tests/EndToEnd.*.Tests.ps1`): `tests/Helpers/TestHttpServer.ps1` starts an `HttpListener` on 127.0.0.1 with a free port in a background runspace, records requests and serves scripted responses; modules generated from the fixtures (petstore 3.0, Swagger 2.0, 3.1, `e2e-api.json` and `unifi-site-manager-1.0.0.json` with `-UnwrapProperty data`) with the real generator are imported with the real engine and called against it (every auth kind, serialisation, bodies, paging, retry on 429 with Retry-After, problem+json errors, downloads, -WhatIf, -ErrorAction, pipelines, persisted contexts, Overrides.ps1).
- Repository guards (`tests/Module.Tests.ps1`): manifest, silent import, exports = FunctionsToExport = Public files, one function per file, approved verbs, a test per function, full help on public commands, identical about topics, BOM on non-ASCII files.
- PSScriptAnalyzer clean with repo settings; bind check on every generated function.
