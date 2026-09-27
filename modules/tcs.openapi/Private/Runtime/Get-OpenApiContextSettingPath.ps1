function Get-OpenApiContextSettingPath {
    <#
    .SYNOPSIS
        Returns the path of the JSON settings file of a persisted context, or the folder that holds them when no service is given.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [string]$Service
    )

    $folder = Join-Path -Path (Get-OpenApiConfigRoot) -ChildPath 'Contexts'
    if ([string]::IsNullOrEmpty($Service)) {
        return $folder
    }
    if ($Service -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw (New-Object System.ArgumentException -ArgumentList "'$Service' is not a valid service name. Use letters, digits, '.', '_' and '-', starting with a letter or digit.")
    }
    return (Join-Path -Path $folder -ChildPath "$Service.json")
}
