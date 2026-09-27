function Write-OpenApiDeprecationWarning {
    <#
    .SYNOPSIS
        Writes a warning that an operation is deprecated, once per service and operation per session.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$OperationId
    )

    $warned = Get-OpenApiModuleState -Name 'TcsOpenApiDeprecationWarned'
    $key = "$Service/$OperationId"
    if ($warned.ContainsKey($key)) {
        return
    }
    $warned[$key] = $true
    Write-Warning -Message "The operation '$OperationId' of the '$Service' API is deprecated and may be removed in a later version of the API."
}
