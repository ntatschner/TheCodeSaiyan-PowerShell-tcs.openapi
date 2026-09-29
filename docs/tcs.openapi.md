---
Module Name: tcs.openapi
Module Guid: fea600e7-039d-4cf2-b288-bbf335757db6
Download Help Link: 
Help Version: 0.3.1
Locale: en-GB
---

# tcs.openapi Module
## Description
Generate PowerShell modules from OpenAPI 3.0/3.1 and Swagger 2.0 documents, plus the shared request engine the generated modules use (auth, parameter serialisation, request bodies, retry, paging, errors and downloads).

## tcs.openapi Cmdlets
### [Get-OpenApiContext](Get-OpenApiContext.md)
Returns the stored connections of OpenAPI services, with every secret shown as ********.

### [Import-OpenApiDocument](Import-OpenApiDocument.md)
Reads an OpenAPI 3.0/3.1 or Swagger 2.0 document and returns the normalised document model.

### [Invoke-OpenApiRequest](Invoke-OpenApiRequest.md)
Sends a request for an OpenAPI operation and returns the response as PowerShell objects.

### [New-OpenApiModule](New-OpenApiModule.md)
Generates a PowerShell module of wrapper commands from an OpenAPI 3.0/3.1 or Swagger 2.0 document.

### [Remove-OpenApiContext](Remove-OpenApiContext.md)
Removes the stored connection of an OpenAPI service.

### [Set-OpenApiContext](Set-OpenApiContext.md)
Stores the connection (base URI, credentials and transport settings) for an OpenAPI service.

### [Test-OpenApiDocument](Test-OpenApiDocument.md)
Checks an OpenAPI or Swagger document and returns its findings.

