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

.PARAMETER Path
    Path of a .json, .yaml or .yml document.

.PARAMETER Uri
    Absolute URL of the document.

.PARAMETER InputObject
    The document text (JSON or YAML).

.PARAMETER Document
    A document model returned by Import-OpenApiDocument; its findings are returned.

.EXAMPLE
    Test-OpenApiDocument -Path ./petstore.json | Format-Table Severity, Code, Pointer, Message

    Lists the findings for a local document.

.EXAMPLE
    if (Test-OpenApiDocument -Uri $url | Where-Object Severity -eq 'Error') { throw 'Fix the document first' }

    Stops a build when the document has errors.

.INPUTS
    System.IO.FileInfo
    Files (or any object with a FullName or Path property) through the pipeline.

.OUTPUTS
    Tcs.OpenApi.Finding
    One object per finding: Severity, Code, Pointer, Message, Operation.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

    New-OpenApiModule adds generator findings (OA040, OA041, OA070) to these.

.LINK
    Import-OpenApiDocument
#>
function Test-OpenApiDocument {
    [CmdletBinding(DefaultParameterSetName = 'Path')]
    [OutputType('Tcs.OpenApi.Finding')]
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
        [pscustomobject]$Document
    )

    begin {
        $telemetry = Start-TcsTelemetry
    }

    process {
        $parameterSet = $PSCmdlet.ParameterSetName
        Invoke-TcsCommand -Token $telemetry -ScriptBlock {
            if ($parameterSet -eq 'Document') {
                $Document.Findings
                return
            }
            $readArguments = @{}
            $readArguments[$parameterSet] = Get-Variable -Name $parameterSet -ValueOnly
            $source = Get-OpenApiDocumentText @readArguments
            $root = ConvertFrom-OpenApiText -Text $source.Text -Format $source.Format
            try {
                $model = ConvertTo-OpenApiDocumentModel -Root $root -BaseUri $source.BaseUri
                $model.Findings
            }
            catch {
                [pscustomobject]@{
                    PSTypeName = 'Tcs.OpenApi.Finding'
                    Severity   = 'Error'
                    Code       = 'OA001'
                    Pointer    = ''
                    Message    = "The document could not be processed: $($_.Exception.Message)"
                    Operation  = $null
                }
            }
        }
    }

    end {
        Complete-TcsTelemetry -Token $telemetry
    }
}
