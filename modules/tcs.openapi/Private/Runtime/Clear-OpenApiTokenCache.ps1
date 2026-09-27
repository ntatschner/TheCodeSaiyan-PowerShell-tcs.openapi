function Clear-OpenApiTokenCache {
    <#
    .SYNOPSIS
        Forgets cached OAuth2 access tokens of one service, or of every service.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$Service
    )

    $cache = Get-OpenApiModuleState -Name 'TcsOpenApiTokenCache'
    if ($null -eq $cache) {
        return
    }
    foreach ($key in @($cache.Keys)) {
        if ([string]::IsNullOrEmpty($Service) -or $key.StartsWith("$Service|")) {
            $cache.Remove($key)
        }
    }
}
