---
external help file: tcs.openapi-help.xml
Module Name: tcs.openapi
online version:
schema: 2.0.0
---

# Import-OpenApiDocument

## SYNOPSIS
Reads an OpenAPI 3.0/3.1 or Swagger 2.0 document and returns the normalised document model.

## SYNTAX

### Path (Default)
```
Import-OpenApiDocument -Path <String> [<CommonParameters>]
```

### Uri
```
Import-OpenApiDocument -Uri <Uri> [<CommonParameters>]
```

### InputObject
```
Import-OpenApiDocument -InputObject <String> [<CommonParameters>]
```

## DESCRIPTION
Import-OpenApiDocument loads a document from a file, a URL or a string, detects its version and
returns one OpenAPI 3-shaped model (PSTypeName Tcs.OpenApi.Document) whatever the input version:
Title, Version, Description, ContactUrl, LicenseName, LicenseUrl, ExternalDocsUrl, Servers,
SecuritySchemes, Security, Schemas, Operations and Findings.

- JSON is always supported.
YAML needs ConvertFrom-Yaml from the powershell-yaml module; without it
  the command stops with an error that says so.
- Swagger 2.0 documents are converted: host/basePath/schemes become Servers, definitions become
  Schemas, body and formData parameters become a RequestBody, collectionFormat becomes style/explode
  and securityDefinitions become SecuritySchemes.
- Local $refs are resolved (circular schemas are marked Recursive); external $refs are reported and
  the operations that use them are flagged Unsupported.
- Problems met while normalising are returned in the model's Findings (see Test-OpenApiDocument).

The model is plain data (PSCustomObject, ordered dictionaries and arrays), so it can be saved with
ConvertTo-Json -Depth 100.

## EXAMPLES

### EXAMPLE 1
```
$doc = Import-OpenApiDocument -Path ./petstore.json
$doc.Operations | Select-Object OperationId, Method, Path
```

Loads a local document and lists its operations.

### EXAMPLE 2
```
Import-OpenApiDocument -Uri 'https://petstore3.swagger.io/api/v3/openapi.json' | Select-Object -ExpandProperty Findings
```

Downloads a document and shows the problems found while normalising it.

### EXAMPLE 3
```
Get-ChildItem -Path ./specs -Filter *.json | Import-OpenApiDocument
```

Imports every JSON document in a folder; Swagger 2.0 documents come back OpenAPI 3-shaped.

## PARAMETERS

### -Path
Path of a .json, .yaml or .yml document.

```yaml
Type: String
Parameter Sets: Path
Aliases: FullName

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByPropertyName)
Accept wildcard characters: False
```

### -Uri
Absolute URL of the document.
It is downloaded with Invoke-WebRequest; relative server URLs in the
document are resolved against it.

```yaml
Type: Uri
Parameter Sets: Uri
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -InputObject
The document text (JSON or YAML).

```yaml
Type: String
Parameter Sets: InputObject
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### System.IO.FileInfo
### Files (or any object with a FullName or Path property) through the pipeline.
## OUTPUTS

### Tcs.OpenApi.Document
### The normalised document model.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

Stops with an error for input that cannot be read or parsed and for documents whose version is not
3.0.x, 3.1.x or Swagger 2.0 (finding OA001).
All other problems are returned as findings.

## RELATED LINKS

[Test-OpenApiDocument]()

[New-OpenApiModule]()

