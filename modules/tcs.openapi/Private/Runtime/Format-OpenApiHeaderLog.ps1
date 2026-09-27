function Format-OpenApiHeaderLog {
    <#
    .SYNOPSIS
        Formats headers as 'Name: value' lines for Debug output, with secret values (Authorization, cookies, api keys) shown as ********.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$Header,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$SensitiveName
    )

    if ($null -eq $Header) {
        return ''
    }
    $lines = foreach ($key in $Header.Keys) {
        $value = @($Header[$key]) -join ', '
        if (Test-OpenApiSensitiveName -Name ([string]$key) -SensitiveName $SensitiveName) {
            $value = '********'
        }
        "  ${key}: $value"
    }
    return (@($lines) -join [Environment]::NewLine)
}
