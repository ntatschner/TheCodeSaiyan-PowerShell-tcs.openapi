function Get-OpenApiGenVersion {
    <#
    .SYNOPSIS
        Returns the version of tcs.openapi, read from its own manifest (tcs.openapi.psd1 in -ModuleRoot).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleRoot
    )

    $manifestPath = Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1'
    $manifest = Import-PowerShellDataFile -Path $manifestPath
    return ([version]$manifest.ModuleVersion).ToString()
}
