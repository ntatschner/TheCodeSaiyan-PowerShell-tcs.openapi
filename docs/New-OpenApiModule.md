---
external help file: tcs.openapi-help.xml
Module Name: tcs.openapi
online version:
schema: 2.0.0
---

# New-OpenApiModule

## SYNOPSIS
Generates a PowerShell module of wrapper commands from an OpenAPI 3.0/3.1 or Swagger 2.0 document.

## SYNTAX

### Document (Default)
```
New-OpenApiModule -Document <PSObject> -ModuleName <String> -OutputPath <String> [-NounPrefix <String>]
 [-UnwrapProperty <String>] [-HelpUri <String>] [-ModuleVersion <Version>] [-Author <String>] [-Force]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Path
```
New-OpenApiModule -Path <String> -ModuleName <String> -OutputPath <String> [-NounPrefix <String>]
 [-UnwrapProperty <String>] [-HelpUri <String>] [-ModuleVersion <Version>] [-Author <String>] [-Force]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

### Uri
```
New-OpenApiModule -Uri <Uri> -ModuleName <String> -OutputPath <String> [-NounPrefix <String>]
 [-UnwrapProperty <String>] [-HelpUri <String>] [-ModuleVersion <Version>] [-Author <String>] [-Force]
 [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
New-OpenApiModule turns an OpenAPI document into a module with one command per operation.
Each
command has PowerShell parameters for the operation's path, query, header and cookie parameters
and for the properties of a JSON request body (or -Body), comment-based help, and calls
Invoke-OpenApiRequest from tcs.openapi, which handles authentication, serialisation, retry,
paging and errors.
The generated module requires tcs.openapi, so fixes to the request engine
reach it without regenerating.

The module is written to \<OutputPath\>/\<ModuleName\>:
  \<ModuleName\>.psd1 / .psm1   manifest and root module
  OpenApi/operations.json     operation metadata used by the request engine
  OpenApi/source.json         the normalised document (for regeneration diffs)
  Public/\<Tag\>/\<Verb\>-\<Noun\>.ps1   one command per operation
  Public/_Connection/         Set-, Get- and Remove-\<Prefix\>Context
  Overrides.ps1               created once, never overwritten: your own changes go here
  README.md                   the list of commands
  en-US/about_\<ModuleName\>.help.txt   the module's about topic

Existing generated files are replaced only with -Force; Overrides.ps1 is never replaced.
The same
document and options always give byte-identical files.
Problems found in the document and by the
generator (renamed commands OA040, commands renamed so they do not shadow a core PowerShell
command OA042, renamed parameters OA041, skipped operations OA070) are
returned in Findings.

Generated commands that can change data have -WhatIf and -Confirm: every DELETE (ConfirmImpact
High), every POST, PUT and PATCH (ConfirmImpact Medium) except Get- and Test- commands, which only
read (for example a query sent as a POST with a body), and any command whose verb changes state
(New, Set, Remove, Start, Stop, Restart, Reset, Update).
Other commands have neither.

The comment-based help of the generated commands is plain text that PlatyPS can turn into
Markdown for MDX sites (Docusaurus, Astro Starlight): HTML and Markdown from the document are
converted, words with '\<', '{' or '}' and the operation ids and paths are code spans, and every
example has a description.
The manifest gets ProjectUri and LicenseUri from the document's
externalDocs, contact and licence URLs.

## EXAMPLES

### EXAMPLE 1
```
New-OpenApiModule -Path ./petstore.json -ModuleName PetStore -OutputPath ./out -NounPrefix PetStore
```

Generates ./out/PetStore with commands such as Get-PetStorePet.

### EXAMPLE 2
```
$document = Import-OpenApiDocument -Uri 'https://api.example.com/openapi.json'
$result = New-OpenApiModule -Document $document -ModuleName Example -NounPrefix Ex -OutputPath ./out -Force
$result.Findings | Where-Object Severity -NE 'Information'
```

Regenerates a module from a downloaded document and lists the warnings and errors.

### EXAMPLE 3
```
New-OpenApiModule -Path ./sitemanager.json -ModuleName UniFi.SiteManager -NounPrefix UniFi -UnwrapProperty data -OutputPath ./out
```

Generates a module whose commands return the 'data' property of the API's responses (Get-UniFiHostById
returns the host, not the { data, httpStatusCode, traceId } envelope).

### EXAMPLE 4
```
New-OpenApiModule -Path ./sitemanager.json -ModuleName UniFi.SiteManager -NounPrefix UniFi -OutputPath ./out -HelpUri 'https://docs.example.com/unifi/{0}'
```

Links every command to its page on a documentation site (Get-Help Get-UniFiHost -Online opens
https://docs.example.com/unifi/Get-UniFiHost).

### EXAMPLE 5
```
New-OpenApiModule -Path ./api.json -ModuleName Example -NounPrefix Ex -OutputPath ./out -WhatIf
```

Shows the files that would be written.

## PARAMETERS

### -Path
The path of the OpenAPI document (JSON, or YAML when powershell-yaml is installed).
Read with
Import-OpenApiDocument.

```yaml
Type: String
Parameter Sets: Path
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Uri
The URL of the OpenAPI document.
Read with Import-OpenApiDocument.

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

### -Document
A document model returned by Import-OpenApiDocument.

```yaml
Type: PSObject
Parameter Sets: Document
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: True (ByValue)
Accept wildcard characters: False
```

### -ModuleName
The name of the module to create (letters, digits, '.', '_' and '-', starting with a letter).
It is
also the service name of the connection context.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -OutputPath
The folder in which the module folder is created.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -NounPrefix
A prefix for every command noun: with 'PetStore', operation getOrder becomes Get-PetStoreOrder.
The connection commands are Set-/Get-/Remove-\<NounPrefix\>Context.
Without it, the connection commands
use the PascalCase module name.

Set it.
There is no default prefix, so without one the nouns come straight from the document
(getItem -\> Get-Item) and easily clash with other modules.
A name that would shadow a core
PowerShell command (Get-Item, New-Item, Get-Content, ...) is never generated: it gets the PascalCase
module name as its prefix instead (Get-\<ModuleName\>Item) and an OA042 warning finding.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UnwrapProperty
The name of a response property that wraps the actual result, such as 'data' for APIs that answer
{ "data": {...}, "traceId": "..." }.
For every operation whose first 2xx JSON response schema is an
object with this property, the command outputs the value of the property instead of the whole
response (array values item by item), typed with the property's schema name when it has one.
It is
applied only when a response actually has the property, never with -Raw, and not to pageable
operations, which output the items of each page already.
Stored per operation in
OpenApi/operations.json (UnwrapProperty).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -HelpUri
The online help address of the generated commands, with {0} where the command name goes, for
example 'https://docs.example.com/unifi/{0}'.
Each command gets it as its HelpUri and first .LINK,
so Get-Help -Online opens it and PlatyPS writes it as 'online version'; the about topic lists it
with {0} = about_\<ModuleName\>.
Without {0} every command links to the same address.
It must be an
absolute http or https URL.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ModuleVersion
The version of the generated module.
Defaults to 0.1.0.

```yaml
Type: Version
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Author
The author written to the manifest.
Defaults to 'tcs.openapi'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Force
Replaces generated files that already exist and differ, and removes generated command files for
operations that are no longer in the document.
Overrides.ps1 is never replaced.

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

### -WhatIf
Shows what would be written without writing anything.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Asks for confirmation before each file is written.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
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

### System.Management.Automation.PSObject
### You can pipe a document model from Import-OpenApiDocument.
## OUTPUTS

### Tcs.OpenApi.GenerationResult
### { ModuleName, Path, ManifestPath, Functions (Name, OperationId, File, Action), Findings, Skipped,
### Files (every file with its action) }.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

The generated code runs on Windows PowerShell 5.1 and PowerShell 7.

## RELATED LINKS

[Import-OpenApiDocument]()

[Invoke-OpenApiRequest]()

