function Remove-OpenApiPersistedContext {
    <#
    .SYNOPSIS
        Deletes the saved settings file and module secrets of a service; returns $true when anything was removed.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Service
    )

    $removed = $false
    $path = Get-OpenApiContextSettingPath -Service $Service
    if (-not $PSCmdlet.ShouldProcess("saved context of '$Service'", 'Remove')) {
        return $false
    }
    foreach ($kind in @('ApiKey', 'BearerToken', 'ClientSecret', 'Credential', 'ProxyCredential')) {
        $secretError = $null
        Remove-ModuleSecret -ModuleName 'tcs.openapi' -Name "$Service.$kind" -Confirm:$false -ErrorAction SilentlyContinue -ErrorVariable secretError
        if (-not $secretError) {
            $removed = $true
        }
    }
    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force -Confirm:$false -ErrorAction Stop
        $removed = $true
    }
    return $removed
}
