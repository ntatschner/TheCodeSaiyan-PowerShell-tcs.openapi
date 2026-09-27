function Get-OpenApiRedactedUri {
    <#
    .SYNOPSIS
        Replaces the values of secret query parameters (api keys and names like token/secret) in a URL with ********.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Uri,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$SensitiveName
    )

    if ([string]::IsNullOrEmpty($Uri)) {
        return $Uri
    }
    $queryIndex = $Uri.IndexOf('?')
    if ($queryIndex -lt 0) {
        return $Uri
    }
    $prefix = $Uri.Substring(0, $queryIndex + 1)
    $query = $Uri.Substring($queryIndex + 1)
    $fragment = ''
    $hashIndex = $query.IndexOf('#')
    if ($hashIndex -ge 0) {
        $fragment = $query.Substring($hashIndex)
        $query = $query.Substring(0, $hashIndex)
    }
    $parts = foreach ($pair in $query.Split('&')) {
        $equals = $pair.IndexOf('=')
        if ($equals -lt 0) {
            $pair
            continue
        }
        $name = [System.Uri]::UnescapeDataString($pair.Substring(0, $equals))
        if (Test-OpenApiSensitiveName -Name $name -SensitiveName $SensitiveName) {
            $pair.Substring(0, $equals + 1) + '********'
        }
        else {
            $pair
        }
    }
    return $prefix + (@($parts) -join '&') + $fragment
}
