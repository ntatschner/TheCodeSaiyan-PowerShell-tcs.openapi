function Get-OpenApiHttpClient {
    <#
    .SYNOPSIS
        Returns the HttpClient shared by all requests of a service, creating it on first use and again when the context's transport settings change.
    #>
    [CmdletBinding()]
    [OutputType([System.Net.Http.HttpClient])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    Import-OpenApiHttpAssembly
    $cache = Get-OpenApiModuleState -Name 'TcsOpenApiHttpClients'
    $proxyUser = $null
    if ($null -ne $Context.ProxyCredential) {
        $proxyUser = $Context.ProxyCredential.UserName
    }
    $signature = '{0}|{1}|{2}|{3}' -f $Context.Proxy, $proxyUser, $Context.SkipCertificateCheck, $Context.TimeoutSec
    $entry = $cache[$Context.Service]
    if ($null -ne $entry) {
        if ($entry.Signature -eq $signature) {
            return $entry.Client
        }
        $entry.Client.Dispose()
        $cache.Remove($Context.Service)
    }

    $handler = New-OpenApiHttpClientHandler -Context $Context
    $client = New-Object System.Net.Http.HttpClient -ArgumentList $handler, $true
    if ($Context.TimeoutSec -gt 0) {
        $client.Timeout = [timespan]::FromSeconds($Context.TimeoutSec)
    }
    else {
        $client.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    }
    $cache[$Context.Service] = [pscustomobject]@{
        Client    = $client
        Signature = $signature
    }
    return $client
}
