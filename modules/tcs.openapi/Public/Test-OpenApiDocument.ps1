<#
.SYNOPSIS
    Checks an OpenAPI or Swagger document and returns its findings.

.DESCRIPTION
    Test-OpenApiDocument returns one finding object (PSTypeName Tcs.OpenApi.Finding) per problem:
    Severity (Error, Warning or Information), Code, Pointer (JSON pointer into the document), Message and
    Operation (operationId, when the finding belongs to one). It covers invalid structure and features
    the generator or runtime do not support:

      OA001  invalid or unsupported document version (Error)
      OA002  missing paths (Error; Warning for 3.1)
      OA010  missing operationId, one is generated (Warning)
      OA011  duplicate operationId, a suffix is added (Warning)
      OA020  external $ref, the operation is flagged Unsupported (Error)
      OA021  unresolved or circular non-schema $ref, undefined security scheme (Error/Warning)
      OA022  circular schema (Information)
      OA030  unsupported security scheme (openIdConnect, oauth2 without clientCredentials...) (Warning)
      OA031  schema with several non-null types (Warning)
      OA050  oneOf/anyOf request body, passed through as -Body only (Information)
      OA051  unsupported request media type, sent as raw string/bytes (Warning)
      OA060  deprecated operation (Information)

    It never throws for problems in the document; it throws only when the input cannot be read or parsed
    (missing file, download failure, invalid JSON/YAML, YAML without powershell-yaml).

    When a document has no findings, nothing is written to the pipeline and a one-line message such as
    "No problems found in api.json (12 operations)." is written to the information stream, which is shown by
    default. -InformationAction SilentlyContinue hides it (it is still recorded by -InformationVariable) and
    -InformationAction Ignore drops it. With -Summary, one summary object is returned
    instead of the findings, even when there are none.

.PARAMETER Path
    Path of a .json, .yaml or .yml document.

.PARAMETER Uri
    Absolute URL of the document.

.PARAMETER InputObject
    The document text (JSON or YAML).

.PARAMETER Document
    A document model returned by Import-OpenApiDocument; its findings are returned.

.PARAMETER Summary
    Returns one Tcs.OpenApi.TestSummary object instead of the individual findings: Source, SourceVersion,
    Operations (count), Errors, Warnings, Information (counts by severity), IsValid ($true when there are no
    errors) and Findings (all findings). Returned even when the document has no findings.

.EXAMPLE
    Test-OpenApiDocument -Path ./petstore.json | Format-Table Severity, Code, Pointer, Message

    Lists the findings for a local document.

.EXAMPLE
    Test-OpenApiDocument -Path ./petstore.json -Summary

    Returns one object with the number of operations and of errors, warnings and information findings.

.EXAMPLE
    if (Test-OpenApiDocument -Uri $url | Where-Object Severity -eq 'Error') { throw 'Fix the document first' }

    Stops a build when the document has errors.

.INPUTS
    System.IO.FileInfo
    Files (or any object with a FullName or Path property) through the pipeline.

.OUTPUTS
    Tcs.OpenApi.Finding
    One object per finding: Severity, Code, Pointer, Message, Operation.

    Tcs.OpenApi.TestSummary
    With -Summary: one object per document.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

    New-OpenApiModule adds generator findings (OA040, OA041, OA042, OA070) to these.

.LINK
    Import-OpenApiDocument
#>
function Test-OpenApiDocument {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType('Tcs.OpenApi.Finding', 'Tcs.OpenApi.TestSummary')]
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
        [string]$InputObject,

        [Parameter(Mandatory, ParameterSetName = 'Document', HelpMessage = 'A model returned by Import-OpenApiDocument.')]
        [PSTypeName('Tcs.OpenApi.Document')]
        [pscustomobject]$Document,

        [Parameter()]
        [switch]$Summary
    )

    begin {
        $telemetry = Start-TcsTelemetry
    }

    process {
        $parameterSet = $PSCmdlet.ParameterSetName
        $results = Invoke-TcsCommand -Token $telemetry -ScriptBlock {
            $findings = @()
            $operationCount = 0
            $sourceVersion = $null
            if ($parameterSet -eq 'Document') {
                $findings = @($Document.Findings)
                $operationCount = @($Document.Operations).Count
                $sourceVersion = $Document.SourceVersion
                $sourceName = 'the document'
                if (-not [string]::IsNullOrEmpty([string]$Document.Title)) {
                    $sourceName = "'$($Document.Title)'"
                }
            }
            else {
                $readArguments = @{}
                $readArguments[$parameterSet] = Get-Variable -Name $parameterSet -ValueOnly
                switch ($parameterSet) {
                    'Path' { $sourceName = Split-Path -Path $Path -Leaf }
                    'Uri' { $sourceName = [string]$Uri }
                    default { $sourceName = 'the document' }
                }
                $source = Get-OpenApiDocumentText @readArguments
                $root = ConvertFrom-OpenApiText -Text $source.Text -Format $source.Format
                try {
                    $model = ConvertTo-OpenApiDocumentModel -Root $root -BaseUri $source.BaseUri
                    $findings = @($model.Findings)
                    $operationCount = @($model.Operations).Count
                    $sourceVersion = $model.SourceVersion
                }
                catch {
                    $findings = @([pscustomobject]@{
                            PSTypeName = 'Tcs.OpenApi.Finding'
                            Severity   = 'Error'
                            Code       = 'OA001'
                            Pointer    = ''
                            Message    = "The document could not be processed: $($_.Exception.Message)"
                            Operation  = $null
                        })
                }
            }

            # One result object (not enumerated); the output is written below, in this function's scope, so
            # -InformationAction and -InformationVariable apply to the message
            , [pscustomobject]@{
                Findings       = $findings
                OperationCount = $operationCount
                SourceVersion  = $sourceVersion
                SourceName     = $sourceName
            }
        }
        foreach ($result in @($results)) {
            $findings = @($result.Findings)
            if ($Summary) {
                $errorCount = @($findings | Where-Object -FilterScript { $_.Severity -eq 'Error' }).Count
                [pscustomobject]@{
                    PSTypeName    = 'Tcs.OpenApi.TestSummary'
                    Source        = $result.SourceName
                    SourceVersion = $result.SourceVersion
                    Operations    = $result.OperationCount
                    Errors        = $errorCount
                    Warnings      = @($findings | Where-Object -FilterScript { $_.Severity -eq 'Warning' }).Count
                    Information   = @($findings | Where-Object -FilterScript { $_.Severity -eq 'Information' }).Count
                    IsValid       = ($errorCount -eq 0)
                    Findings      = $findings
                }
                continue
            }
            if ($findings.Count -eq 0) {
                $plural = 's'
                if ($result.OperationCount -eq 1) {
                    $plural = ''
                }
                $message = "No problems found in $($result.SourceName) ($($result.OperationCount) operation$plural)."
                if ($PSBoundParameters.ContainsKey('InformationAction')) {
                    # Passed explicitly: with -InformationAction Ignore, Windows PowerShell 5.1 sets
                    # $InformationPreference to Ignore here and Write-Information then throws when it reads it
                    Write-Information -MessageData $message -InformationAction $PSBoundParameters['InformationAction']
                }
                else {
                    # Shown by default so an empty result is not mistaken for the command doing nothing
                    Write-Information -MessageData $message -InformationAction Continue
                }
                continue
            }
            $findings
        }
    }

    end {
        Complete-TcsTelemetry -Token $telemetry
    }
}
