function Add-OpenApiFinding {
    <#
    .SYNOPSIS
        Adds a finding { Severity, Code, Pointer, Message, Operation } to a normalisation context (once per code, pointer and operation).
    .DESCRIPTION
        Operation defaults to the operation being normalised. For Swagger 2.0 documents, pointers into
        the converted components are mapped back to the original '/definitions' and '/securityDefinitions'.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Warning', 'Information')]
        [string]$Severity,

        [Parameter(Mandatory)]
        [string]$Code,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer,

        [Parameter(Mandatory)]
        [string]$Message,

        [AllowNull()]
        [string]$Operation
    )

    if (-not $PSBoundParameters.ContainsKey('Operation')) {
        $Operation = $Context.CurrentOperation
    }
    if ([string]::IsNullOrEmpty($Operation)) {
        $Operation = $null
    }
    if ($Context.SourceVersion -eq '2.0') {
        if ($Pointer.StartsWith('/components/schemas')) {
            $Pointer = '/definitions' + $Pointer.Substring('/components/schemas'.Length)
        }
        elseif ($Pointer.StartsWith('/components/securitySchemes')) {
            $Pointer = '/securityDefinitions' + $Pointer.Substring('/components/securitySchemes'.Length)
        }
    }
    $key = '{0}|{1}|{2}' -f $Code, $Pointer, $Operation
    if (-not $Context.FindingKeys.Add($key)) {
        return
    }
    $Context.Findings.Add([pscustomobject]@{
            PSTypeName = 'Tcs.OpenApi.Finding'
            Severity   = $Severity
            Code       = $Code
            Pointer    = $Pointer
            Message    = $Message
            Operation  = $Operation
        })
}
