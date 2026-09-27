# tcs.openapi

Generates PowerShell modules from OpenAPI 3.0/3.1 and Swagger 2.0 documents, and is the request engine those
modules use (authentication, parameter serialisation, request bodies, retry, paging, errors and downloads).
Runs on Windows PowerShell 5.1 and PowerShell 7; requires tcs.core 0.4.1.

```powershell
New-OpenApiModule -Path ./petstore.json -ModuleName PetStore -NounPrefix PetStore -OutputPath ./out
Import-Module ./out/PetStore/PetStore.psd1
Set-PetStoreContext -ApiKey (Read-Host -AsSecureString -Prompt 'API key')
Get-PetStorePet -All
```

| Command | Purpose |
|---|---|
| `Import-OpenApiDocument` | Reads a document (file, URL or string) into the normalised model |
| `Test-OpenApiDocument` | Lists findings: invalid structure and unsupported features |
| `New-OpenApiModule` | Writes a module with one command per operation |
| `Set-OpenApiContext` / `Get-OpenApiContext` / `Remove-OpenApiContext` | Manage the connection of a service |
| `Invoke-OpenApiRequest` | The engine the generated commands call; usable directly |

See `Get-Help about_tcs.openapi` and https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.openapi.
