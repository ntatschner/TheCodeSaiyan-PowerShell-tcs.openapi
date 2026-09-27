---
external help file: tcs.openapi-help.xml
Module Name: tcs.openapi
online version:
schema: 2.0.0
---

# Test-OpenApiDocument

## SYNOPSIS
Checks an OpenAPI or Swagger document and returns its findings.

## SYNTAX

### Path (Default)
```
Test-OpenApiDocument -Path <String> [-Summary] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Uri
```
Test-OpenApiDocument -Uri <Uri> [-Summary] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### InputObject
```
Test-OpenApiDocument -InputObject <String> [-Summary] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

### Document
```
Test-OpenApiDocument -Document <PSObject> [-Summary] [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
Test-OpenApiDocument returns one finding object (PSTypeName Tcs.OpenApi.Finding) per problem:
Severity (Error, Warning or Information), Code, Pointer (JSON pointer into the document), Message and
Operation (operationId, when the finding belongs to one).
It covers invalid structure and features
the generator or runtime do not support:

  OA001  invalid or unsupported document version (Error)
  OA002  missing paths (Error; Warning for 3.1)
  OA010  missing operationId, one is generated (Warning)
  OA011  duplicate operationId, a suffix is added (Warning)
  OA020  external $ref, the operation is flagged Unsupported (Error)
  OA021  unresolved or circular non-schema $ref, undefined security scheme (Error/Warning)
  OA022  circular schema (Information)
  OA023  path parameter that is not in the path template, ignored (Warning)
  OA024  path template placeholder without a path parameter (Error)
  OA030  unsupported security scheme (openIdConnect, oauth2 without clientCredentials...) (Warning)
  OA031  schema with several non-null types (Warning)
  OA050  oneOf/anyOf request body, passed through as -Body only (Information)
  OA051  unsupported request media type, sent as raw string/bytes (Warning)
  OA060  deprecated operation (Information)

It never throws for problems in the document; it throws only when the input cannot be read or parsed
(missing file, download failure, invalid JSON/YAML, YAML without powershell-yaml).

When a document has no findings, nothing is written to the pipeline and a one-line message such as
"No problems found in api.json (12 operations)." is written to the information stream, which is shown by
default.
-InformationAction SilentlyContinue hides it (it is still recorded by -InformationVariable) and
-InformationAction Ignore drops it.
With -Summary, one summary object is returned
instead of the findings, even when there are none.

## EXAMPLES

### EXAMPLE 1
```
Test-OpenApiDocument -Path ./petstore.json | Format-Table Severity, Code, Pointer, Message
```

Lists the findings for a local document.

### EXAMPLE 2
```
Test-OpenApiDocument -Path ./petstore.json -Summary
```

Returns one object with the number of operations and of errors, warnings and information findings.

### EXAMPLE 3
```
if (Test-OpenApiDocument -Uri $url | Where-Object Severity -eq 'Error') { throw 'Fix the document first' }
```

Stops a build when the document has errors.

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

### -Document
A document model returned by Import-OpenApiDocument; its findings are returned.

```yaml
Type: PSObject
Parameter Sets: Document
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Summary
Returns one Tcs.OpenApi.TestSummary object instead of the individual findings: Source, SourceVersion,
Operations (count), Errors, Warnings, Information (counts by severity), IsValid ($true when there are no
errors) and Findings (all findings).
Returned even when the document has no findings.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
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

### Tcs.OpenApi.Finding
### One object per finding: Severity, Code, Pointer, Message, Operation.
### Tcs.OpenApi.TestSummary
### With -Summary: one object per document.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

New-OpenApiModule adds generator findings (OA040, OA041, OA042, OA070) to these.

## RELATED LINKS

[Import-OpenApiDocument]()

