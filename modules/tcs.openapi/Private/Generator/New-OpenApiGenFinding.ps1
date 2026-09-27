function New-OpenApiGenFinding {
    <#
    .SYNOPSIS
        Creates a generator finding { Severity, Code, Pointer, Message, Operation } for an operation.

    .DESCRIPTION
        The pointer is the JSON pointer of the operation ('/paths/~1pets~1{petId}/get'), with an optional
        suffix such as '/parameters/debug'.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only; it changes no state.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warning', 'Information')]
        [string]$Severity,

        [Parameter(Mandatory = $true)]
        [string]$Code,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [AllowNull()]
        [object]$Operation,

        [Parameter()]
        [string]$PointerSuffix = ''
    )

    $pointer = ''
    $operationId = $null
    if ($null -ne $Operation) {
        $escapedPath = ([string]$Operation.Path).Replace('~', '~0').Replace('/', '~1')
        $pointer = '/paths/' + $escapedPath + '/' + ([string]$Operation.Method).ToLowerInvariant()
        $operationId = $Operation.OperationId
    }
    return [pscustomobject]@{
        PSTypeName = 'Tcs.OpenApi.Finding'
        Severity   = $Severity
        Code       = $Code
        Pointer    = $pointer + $PointerSuffix
        Message    = $Message
        Operation  = $operationId
    }
}
