function Get-OpenApiConfigRoot {
    <#
    .SYNOPSIS
        Returns the tcs.openapi settings folder under the tcs.core configuration root (TCS_CONFIG_ROOT or <ApplicationData>/PowerShell/Config).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # Same resolution as tcs.core's private Get-ModuleConfigRoot, so settings sit next to the secrets
    $root = $env:TCS_CONFIG_ROOT
    if ([string]::IsNullOrWhiteSpace($root)) {
        $appData = [Environment]::GetFolderPath('ApplicationData')
        if ([string]::IsNullOrWhiteSpace($appData)) {
            $appData = [System.IO.Path]::GetTempPath()
        }
        $root = Join-Path -Path (Join-Path -Path $appData -ChildPath 'PowerShell') -ChildPath 'Config'
    }
    return (Join-Path -Path $root -ChildPath 'tcs.openapi')
}
