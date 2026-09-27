function Write-OpenApiDeprecationWarning {
    <#
    .SYNOPSIS
        Writes a warning that an operation is deprecated, once per service and operation per session (through -Cmdlet when given).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter(Mandatory)]
        [string]$OperationId,

        [Parameter()]
        [AllowNull()]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $warned = Get-OpenApiModuleState -Name 'TcsOpenApiDeprecationWarned'
    $key = "$Service/$OperationId"
    if ($warned.ContainsKey($key)) {
        return
    }
    $warned[$key] = $true
    $message = "The operation '$OperationId' of the '$Service' API is deprecated and may be removed in a later version of the API."
    if ($null -ne $Cmdlet) {
        # Written through the calling command, so its -WarningAction and -WarningVariable apply
        $Cmdlet.WriteWarning($message)
    }
    else {
        Write-Warning -Message $message
    }
}
