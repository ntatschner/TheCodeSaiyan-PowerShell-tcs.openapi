function Build-OpenApiHttpClientHandler {
    <#
    .SYNOPSIS
        Creates the HttpClientHandler for a context: automatic decompression, proxy and proxy credentials, and certificate checks.
    #>
    [CmdletBinding()]
    [OutputType([System.Net.Http.HttpClientHandler])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    $handler = New-Object System.Net.Http.HttpClientHandler
    $handler.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    # Cookies are sent from parameters as one Cookie header, not from a container
    $handler.UseCookies = $false
    $handler.AllowAutoRedirect = $true
    if (-not [string]::IsNullOrEmpty($Context.Proxy)) {
        $webProxy = New-Object System.Net.WebProxy -ArgumentList ([uri]$Context.Proxy)
        if ($null -ne $Context.ProxyCredential) {
            $webProxy.Credentials = $Context.ProxyCredential.GetNetworkCredential()
        }
        $handler.Proxy = $webProxy
        $handler.UseProxy = $true
    }
    if ($Context.SkipCertificateCheck) {
        $handler.ServerCertificateCustomValidationCallback = Get-OpenApiCertificateBypassCallback
    }
    return $handler
}
