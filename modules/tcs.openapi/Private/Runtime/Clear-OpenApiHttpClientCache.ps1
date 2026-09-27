function Clear-OpenApiHttpClientCache {
    <#
    .SYNOPSIS
        Disposes the cached HttpClient of one service, or of every service (called when the module is removed).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter()]
        [string]$Service
    )

    $cache = Get-OpenApiModuleState -Name 'TcsOpenApiHttpClients'
    if ($null -eq $cache) {
        return
    }
    $keys = @($cache.Keys)
    if (-not [string]::IsNullOrEmpty($Service)) {
        $keys = @($keys | Where-Object -FilterScript { $_ -eq $Service })
    }
    foreach ($key in $keys) {
        try {
            $cache[$key].Client.Dispose()
        }
        catch {
            Write-Verbose -Message "Could not dispose the HTTP client of '$key': $($_.Exception.Message)"
        }
        $cache.Remove($key)
    }
}
