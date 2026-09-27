function Test-OpenApiSensitiveName {
    <#
    .SYNOPSIS
        Tests whether a header, query or property name holds a secret (Authorization, cookies, api keys, names like password/secret/token).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$SensitiveName
    )

    if ([string]::IsNullOrEmpty($Name)) {
        return $false
    }
    foreach ($candidate in @($SensitiveName)) {
        if (-not [string]::IsNullOrEmpty($candidate) -and $candidate -eq $Name) {
            return $true
        }
    }
    if ($Name -match '^(authorization|proxy-authorization|cookie|set-cookie)$') {
        return $true
    }
    return ($Name -match '(password|passwd|secret|token|api[-_]?key|client_secret|signature|credential)')
}
