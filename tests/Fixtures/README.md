# Test fixtures

Shared OpenAPI/Swagger documents for the tcs.openapi tests. Each part prefixes its own fixtures with its
name (`document-*`, `generator-*`, `runtime-*`, ...).

## Document layer (`document-*`)

Used by `modules/tcs.openapi/Private/Document/Tests` and the `Import-OpenApiDocument` /
`Test-OpenApiDocument` tests.

| Fixture | Exercises |
|---|---|
| `document-petstore-3.0.json` | OpenAPI 3.0.3 petstore: info, servers with variables and a relative server, default security, apiKey/basic/bearer/oauth2 clientCredentials schemes, component parameters/requestBodies/responses/headers `$ref`s, path-level parameter merge, `security: []` vs a list, deprecated operation (OA060), `x-ps-verb`/`x-ps-noun`/`x-ps-name` extensions, externalDocs, JSON-first media type ordering, `application/xml` request body (OA051), binary request/response bodies, missing operationId (OA010), nextLink paging (object with one array + `nextLink`) and Link-header paging (array body + `Link` header). |
| `document-petstore-3.0.yaml` | YAML copy of `document-petstore-3.0.json`; the YAML path must give the same model as the JSON one (ConvertFrom-Yaml is stubbed in the tests). |
| `document-openapi-3.1.json` | OpenAPI 3.1.0: type arrays (`["string","null"]` -> nullable, `["string","integer"]` -> OA031), `type: "null"`, `const`, `examples`, boolean schemas, `x-ms-pageable` (with `itemName`, and `nextLinkName: null` = no paging), webhooks (ignored), unsupported security schemes (openIdConnect, authorizationCode-only oauth2, mutualTLS, http digest -> OA030). |
| `document-swagger-2.0.json` | Swagger 2.0 conversion: host/basePath/schemes -> servers, global and per-operation consumes/produces, `definitions` + `#/definitions` refs, `#/parameters` and `#/responses` refs, body parameter -> requestBody, formData -> `application/x-www-form-urlencoded`, formData with a file -> `multipart/form-data`, collectionFormat csv/multi/pipes/ssv and header arrays -> style/explode, `type: file` responses, response headers, path-level parameter override, securityDefinitions basic/apiKey/oauth2 application (-> clientCredentials)/implicit (OA030), document/path/operation `x-` extensions. |
| `document-circular.json` | Circular schemas: self reference (`Node`), indirect cycle (`Person` -> `Company` -> `Person`), an alias schema that is only a `$ref`; Recursive stubs and OA022. |
| `document-external-ref.json` | External `$ref`s in an operation parameter schema, a parameter itself and a component schema used by an operation (OA020, operations flagged Unsupported), plus an unresolved local ref (OA021). |
| `document-path-parameters.json` | Path-level parameters (including a `$ref`) merged with operation parameters (operation wins; header names case-insensitive), parameter `$ref` chains, deepObject/label styles, cookie and `allowReserved` parameters, a `content`-based parameter, duplicate operationIds differing only in case (OA011), missing operationIds (OA010) and a generated id that collides with an explicit one, JSON-pointer escaping (`a~1b~0c`) and percent-encoded refs. |
| `document-composition.json` | `allOf` merge into Properties/Required (own properties win), discriminator, `oneOf`/`anyOf` request bodies (OA050), nullable `allOf` wrapper, `$ref` with a sibling description, additionalProperties (schema and `false`), inferred object/array types, readOnly/writeOnly, multipart encoding, `*/*+json` ordering. |
| `document-path-templates.json` | Path templates: a router-style catch-all segment (`/consoles/{id}/*path`, path-level parameters) and `{rest*}` (CatchAll), a path parameter missing from the template (OA023) and a placeholder without a parameter (OA024). |

## Real-world documents

| Fixture | Exercises |
|---|---|
| `unifi-site-manager-1.0.0.json` | The UniFi Site Manager API 1.0.0 as published (added with the owner's approval): catch-all connector paths (`/v1/connector/consoles/{id}/*path`) with operationIds that end with the method (`ConnectorGet`), `nextToken` token paging with a `data` array, the `{ data, httpStatusCode, traceId }` envelope (`-UnwrapProperty data`), an `X-API-Key` api key and a `hostIds[]` array query parameter. Used by `tests/EndToEnd.UniFi.Tests.ps1` and the `Test-OpenApiDocument` tests. |
