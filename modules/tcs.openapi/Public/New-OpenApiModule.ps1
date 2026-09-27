<#
.SYNOPSIS
    Generates a PowerShell module of wrapper commands from an OpenAPI 3.0/3.1 or Swagger 2.0 document.

.DESCRIPTION
    New-OpenApiModule turns an OpenAPI document into a module with one command per operation. Each
    command has PowerShell parameters for the operation's path, query, header and cookie parameters
    and for the properties of a JSON request body (or -Body), comment-based help, and calls
    Invoke-OpenApiRequest from tcs.openapi, which handles authentication, serialisation, retry,
    paging and errors. The generated module requires tcs.openapi, so fixes to the request engine
    reach it without regenerating.

    The module is written to <OutputPath>/<ModuleName>:
      <ModuleName>.psd1 / .psm1   manifest and root module
      OpenApi/operations.json     operation metadata used by the request engine
      OpenApi/source.json         the normalised document (for regeneration diffs)
      Public/<Tag>/<Verb>-<Noun>.ps1   one command per operation
      Public/_Connection/         Set-, Get- and Remove-<Prefix>Context
      Overrides.ps1               created once, never overwritten: your own changes go here
      README.md                   the list of commands

    Existing generated files are replaced only with -Force; Overrides.ps1 is never replaced. The same
    document and options always give byte-identical files. Problems found in the document and by the
    generator (renamed commands OA040, commands renamed so they do not shadow a core PowerShell
    command OA042, renamed parameters OA041, skipped operations OA070) are
    returned in Findings.

.PARAMETER Path
    The path of the OpenAPI document (JSON, or YAML when powershell-yaml is installed). Read with
    Import-OpenApiDocument.

.PARAMETER Uri
    The URL of the OpenAPI document. Read with Import-OpenApiDocument.

.PARAMETER Document
    A document model returned by Import-OpenApiDocument.

.PARAMETER ModuleName
    The name of the module to create (letters, digits, '.', '_' and '-', starting with a letter). It is
    also the service name of the connection context.

.PARAMETER OutputPath
    The folder in which the module folder is created.

.PARAMETER NounPrefix
    A prefix for every command noun: with 'PetStore', operation getOrder becomes Get-PetStoreOrder.
    The connection commands are Set-/Get-/Remove-<NounPrefix>Context. Without it, the connection commands
    use the PascalCase module name.

    Set it. There is no default prefix, so without one the nouns come straight from the document
    (getItem -> Get-Item) and easily clash with other modules. A name that would shadow a core
    PowerShell command (Get-Item, New-Item, Get-Content, ...) is never generated: it gets the PascalCase
    module name as its prefix instead (Get-<ModuleName>Item) and an OA042 warning finding.

.PARAMETER ModuleVersion
    The version of the generated module. Defaults to 0.1.0.

.PARAMETER Author
    The author written to the manifest. Defaults to 'tcs.openapi'.

.PARAMETER Force
    Replaces generated files that already exist and differ, and removes generated command files for
    operations that are no longer in the document. Overrides.ps1 is never replaced.

.PARAMETER WhatIf
    Shows what would be written without writing anything.

.PARAMETER Confirm
    Asks for confirmation before each file is written.

.INPUTS
    System.Management.Automation.PSObject
    You can pipe a document model from Import-OpenApiDocument.

.OUTPUTS
    Tcs.OpenApi.GenerationResult
    { ModuleName, Path, ManifestPath, Functions (Name, OperationId, File, Action), Findings, Skipped,
    Files (every file with its action) }.

.EXAMPLE
    New-OpenApiModule -Path ./petstore.json -ModuleName PetStore -OutputPath ./out -NounPrefix PetStore

    Generates ./out/PetStore with commands such as Get-PetStorePet.

.EXAMPLE
    $document = Import-OpenApiDocument -Uri 'https://api.example.com/openapi.json'
    $result = New-OpenApiModule -Document $document -ModuleName Example -OutputPath ./out -Force
    $result.Findings | Where-Object Severity -NE 'Information'

    Regenerates a module from a downloaded document and lists the warnings and errors.

.EXAMPLE
    New-OpenApiModule -Path ./api.json -ModuleName Example -OutputPath ./out -WhatIf

    Shows the files that would be written.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

    The generated code runs on Windows PowerShell 5.1 and PowerShell 7.

.LINK
    Import-OpenApiDocument

.LINK
    Invoke-OpenApiRequest
#>
function New-OpenApiModule {
    [CmdletBinding(DefaultParameterSetName = 'Document', SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    [OutputType('Tcs.OpenApi.GenerationResult')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true, ParameterSetName = 'Uri')]
        [ValidateNotNullOrEmpty()]
        [uri]$Uri,

        [Parameter(Mandatory = $true, ParameterSetName = 'Document', ValueFromPipeline = $true)]
        [ValidateNotNull()]
        [psobject]$Document,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9._-]*$')]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9]*$')]
        [string]$NounPrefix,

        [Parameter()]
        [version]$ModuleVersion,

        [Parameter()]
        [string]$Author,

        [Parameter()]
        [switch]$Force
    )

    process {
        $parameterSetName = $PSCmdlet.ParameterSetName
        Invoke-TcsCommand -ScriptBlock {
            if ($parameterSetName -ne 'Document') {
                $importCommand = Get-Command -Name 'Import-OpenApiDocument' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue
                if ($null -eq $importCommand) {
                    throw 'New-OpenApiModule -Path and -Uri need Import-OpenApiDocument, which is not available. Import the document yourself and pass it with -Document.'
                }
                if ($parameterSetName -eq 'Path') {
                    $Document = & $importCommand -Path $Path
                }
                else {
                    $Document = & $importCommand -Uri $Uri
                }
            }
            if ($null -eq $Document.Operations -and $null -eq $Document.PSObject.Properties['Operations']) {
                throw 'The document is not an OpenAPI document model: it has no Operations. Use Import-OpenApiDocument to read the document.'
            }

            $moduleRoot = Split-Path -Path $PSScriptRoot -Parent
            $option = Resolve-OpenApiGenOption -ModuleName $ModuleName -OutputPath ($PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputPath)) -NounPrefix $NounPrefix -ModuleVersion $ModuleVersion -Author $Author -GeneratorVersion (Get-OpenApiGenVersion -ModuleRoot $moduleRoot)
            $templates = Get-OpenApiGenTemplate -Path (Join-Path -Path $moduleRoot -ChildPath 'Templates')
            $plan = New-OpenApiGenPlan -Document $Document -Option $option -Template $templates
            $written = @(Write-OpenApiGenPlan -Plan $plan -Force:$Force -WhatIf:$WhatIfPreference)

            $actions = @{}
            foreach ($file in $written) {
                $actions[$file.RelativePath] = $file.Action
            }
            $functions = @(foreach ($function in $plan.Functions) {
                    [pscustomobject]@{
                        PSTypeName  = 'Tcs.OpenApi.GeneratedFunction'
                        Name        = $function.Name
                        OperationId = $function.OperationId
                        File        = $function.File
                        Action      = $actions[$function.File]
                    }
                })
            [pscustomobject]@{
                PSTypeName   = 'Tcs.OpenApi.GenerationResult'
                ModuleName   = $plan.ModuleName
                Path         = $plan.ModulePath
                ManifestPath = $plan.ManifestPath
                Functions    = $functions
                Findings     = @(@($Document.Findings) + @($plan.Findings) | Where-Object -FilterScript { $null -ne $_ })
                Skipped      = @($plan.Skipped)
                Files        = $written
            }
        }
    }
}
