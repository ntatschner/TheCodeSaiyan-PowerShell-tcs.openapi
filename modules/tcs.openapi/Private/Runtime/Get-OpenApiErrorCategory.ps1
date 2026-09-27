function Get-OpenApiErrorCategory {
    <#
    .SYNOPSIS
        Maps an HTTP status code to a PowerShell ErrorCategory.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorCategory])]
    param(
        [Parameter(Mandatory)]
        [int]$StatusCode
    )

    $category = switch ($StatusCode) {
        400 { 'InvalidArgument' }
        401 { 'AuthenticationError' }
        403 { 'PermissionDenied' }
        404 { 'ObjectNotFound' }
        405 { 'InvalidOperation' }
        406 { 'InvalidType' }
        408 { 'OperationTimeout' }
        409 { 'ResourceExists' }
        410 { 'ObjectNotFound' }
        412 { 'InvalidOperation' }
        413 { 'LimitsExceeded' }
        415 { 'InvalidType' }
        422 { 'InvalidData' }
        429 { 'LimitsExceeded' }
        500 { 'InvalidResult' }
        501 { 'NotImplemented' }
        502 { 'ResourceUnavailable' }
        503 { 'ResourceUnavailable' }
        504 { 'OperationTimeout' }
        default {
            if ($StatusCode -ge 400 -and $StatusCode -lt 500) {
                'InvalidOperation'
            }
            else {
                'NotSpecified'
            }
        }
    }
    return [System.Management.Automation.ErrorCategory]$category
}
