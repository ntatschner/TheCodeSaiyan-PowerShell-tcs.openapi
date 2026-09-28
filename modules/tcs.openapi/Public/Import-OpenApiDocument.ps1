<#
.SYNOPSIS
    Reads an OpenAPI 3.0/3.1 or Swagger 2.0 document and returns the normalised document model.

.DESCRIPTION
    Import-OpenApiDocument loads a document from a file, a URL or a string, detects its version and
    returns one OpenAPI 3-shaped model (PSTypeName Tcs.OpenApi.Document) whatever the input version:
    Title, Version, Description, ContactUrl, LicenseName, LicenseUrl, ExternalDocsUrl, Servers,
    SecuritySchemes, Security, Schemas, Operations and Findings.

    - JSON is always supported. YAML needs ConvertFrom-Yaml from the powershell-yaml module; without it
      the command stops with an error that says so.
    - Swagger 2.0 documents are converted: host/basePath/schemes become Servers, definitions become
      Schemas, body and formData parameters become a RequestBody, collectionFormat becomes style/explode
      and securityDefinitions become SecuritySchemes.
    - Local $refs are resolved (circular schemas are marked Recursive); external $refs are reported and
      the operations that use them are flagged Unsupported.
    - Problems met while normalising are returned in the model's Findings (see Test-OpenApiDocument).

    The model is plain data (PSCustomObject, ordered dictionaries and arrays), so it can be saved with
    ConvertTo-Json -Depth 100.

.PARAMETER Path
    Path of a .json, .yaml or .yml document.

.PARAMETER Uri
    Absolute URL of the document. It is downloaded with Invoke-WebRequest; relative server URLs in the
    document are resolved against it.

.PARAMETER InputObject
    The document text (JSON or YAML).

.EXAMPLE
    $doc = Import-OpenApiDocument -Path ./petstore.json
    $doc.Operations | Select-Object OperationId, Method, Path

    Loads a local document and lists its operations.

.EXAMPLE
    Import-OpenApiDocument -Uri 'https://petstore3.swagger.io/api/v3/openapi.json' | Select-Object -ExpandProperty Findings

    Downloads a document and shows the problems found while normalising it.

.EXAMPLE
    Get-ChildItem -Path ./specs -Filter *.json | Import-OpenApiDocument

    Imports every JSON document in a folder; Swagger 2.0 documents come back OpenAPI 3-shaped.

.INPUTS
    System.IO.FileInfo
    Files (or any object with a FullName or Path property) through the pipeline.

.OUTPUTS
    Tcs.OpenApi.Document
    The normalised document model.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

    Stops with an error for input that cannot be read or parsed and for documents whose version is not
    3.0.x, 3.1.x or Swagger 2.0 (finding OA001). All other problems are returned as findings.

.LINK
    Test-OpenApiDocument

.LINK
    New-OpenApiModule
#>
function Import-OpenApiDocument {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType('Tcs.OpenApi.Document')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path', ValueFromPipelineByPropertyName, HelpMessage = 'Path of a .json, .yaml or .yml document.')]
        [Alias('FullName')]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Uri', HelpMessage = 'Absolute URL of the document.')]
        [ValidateNotNull()]
        [uri]$Uri,

        [Parameter(Mandatory, ParameterSetName = 'InputObject', HelpMessage = 'The document text (JSON or YAML).')]
        [AllowEmptyString()]
        [string]$InputObject
    )

    begin {
        $telemetry = Start-TcsTelemetry
        $lastError = $null
    }

    process {
        $parameterSet = $PSCmdlet.ParameterSetName
        $completed = $false
        try {
            $readArguments = @{}
            $readArguments[$parameterSet] = Get-Variable -Name $parameterSet -ValueOnly
            $source = Get-OpenApiDocumentText @readArguments
            Write-Verbose "Reading OpenAPI document from '$($source.Source)'."
            $root = ConvertFrom-OpenApiText -Text $source.Text -Format $source.Format
            $model = ConvertTo-OpenApiDocumentModel -Root $root -BaseUri $source.BaseUri

            $versionFinding = @($model.Findings | Where-Object { $_.Code -eq 'OA001' }) | Select-Object -First 1
            if ($null -ne $versionFinding) {
                $exception = New-Object -TypeName System.NotSupportedException -ArgumentList "$($source.Source): $($versionFinding.Message)"
                $record = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'OpenApi.UnsupportedVersion', ([System.Management.Automation.ErrorCategory]::InvalidData), $source.Source
                # ThrowTerminatingError skips the catch block below; only finally runs
                $lastError = $record
                $PSCmdlet.ThrowTerminatingError($record)
            }
            foreach ($finding in $model.Findings) {
                Write-Verbose "$($finding.Severity) $($finding.Code) $($finding.Pointer): $($finding.Message)"
            }
            $model
            $completed = $true
        }
        catch {
            $lastError = $_
            throw
        }
        finally {
            # end does not run when a later command stops the pipeline (Select-Object -First)
            if (-not $completed) {
                Complete-TcsTelemetry -Token $telemetry -ErrorRecord $lastError
            }
        }
    }

    end {
        Complete-TcsTelemetry -Token $telemetry -ErrorRecord $lastError
    }
}
