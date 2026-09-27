function Get-OpenApiOAuthToken {
    <#
    .SYNOPSIS
        Returns an OAuth2 client-credentials access token for a context, from the cache or from the token endpoint (cached until 60 s before expiry).
    #>
    [CmdletBinding()]
    [OutputType([System.Security.SecureString])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [System.Net.Http.HttpClient]$Client,

        [Parameter(Mandatory)]
        [string]$TokenUri,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Scope,

        [Parameter()]
        [switch]$Force
    )

    $cache = Get-OpenApiModuleState -Name 'TcsOpenApiTokenCache'
    $scopeText = (@($Scope | Where-Object -FilterScript { -not [string]::IsNullOrEmpty($_) }) -join ' ')
    $key = '{0}|{1}|{2}|{3}' -f $Context.Service, $TokenUri, $Context.ClientId, $scopeText
    $entry = $cache[$key]
    if (-not $Force -and $null -ne $entry -and $entry.ExpiresAt -gt [datetime]::UtcNow) {
        return $entry.Token
    }

    $form = [ordered]@{
        grant_type    = 'client_credentials'
        client_id     = $Context.ClientId
        client_secret = ConvertFrom-OpenApiSecureString -SecureString $Context.ClientSecret
    }
    if ($scopeText.Length -gt 0) {
        $form['scope'] = $scopeText
    }
    $bodyText = ConvertTo-OpenApiFormBody -InputObject $form
    $form = $null
    $request = New-Object System.Net.Http.HttpRequestMessage -ArgumentList ([System.Net.Http.HttpMethod]::Post), ([uri]$TokenUri)
    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $request.Content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $utf8.GetBytes($bodyText))
    $request.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/x-www-form-urlencoded')
    [void]$request.Headers.TryAddWithoutValidation('Accept', 'application/json')
    Write-Verbose -Message "POST $TokenUri (OAuth2 client credentials token request)"
    Write-Debug -Message ("Token request body: " + (Get-OpenApiRedactedText -Text $bodyText))
    $bodyText = $null
    try {
        try {
            $response = $Client.SendAsync($request).GetAwaiter().GetResult()
        }
        catch {
            $inner = $_.Exception
            while ($inner -is [System.Management.Automation.MethodInvocationException] -and $null -ne $inner.InnerException) {
                $inner = $inner.InnerException
            }
            throw (New-Object System.Security.Authentication.AuthenticationException -ArgumentList "The OAuth2 token request to $TokenUri failed: $($inner.Message)", $inner)
        }
        try {
            $text = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $status = [int]$response.StatusCode
            Write-Verbose -Message "Token response: $status $($response.ReasonPhrase)"
            if ($status -lt 200 -or $status -gt 299) {
                $detail = $response.ReasonPhrase
                try {
                    $problem = $text | ConvertFrom-Json -ErrorAction Stop
                    if ($problem.error_description) {
                        $detail = "$($problem.error): $($problem.error_description)"
                    }
                    elseif ($problem.error) {
                        $detail = [string]$problem.error
                    }
                }
                catch {
                    Write-Debug -Message 'The token error response is not JSON.'
                }
                throw (New-Object System.Security.Authentication.AuthenticationException -ArgumentList "The OAuth2 token request to $TokenUri failed with $status ($detail).")
            }
            $token = $text | ConvertFrom-Json -ErrorAction Stop
        }
        finally {
            $response.Dispose()
        }
    }
    finally {
        $request.Dispose()
    }
    if ([string]::IsNullOrEmpty($token.access_token)) {
        throw (New-Object System.Security.Authentication.AuthenticationException -ArgumentList "The OAuth2 token response from $TokenUri has no access_token.")
    }
    $lifetime = 3600
    if ($null -ne $token.expires_in) {
        $lifetime = [double]$token.expires_in
    }
    $secure = New-Object System.Security.SecureString
    foreach ($character in ([string]$token.access_token).ToCharArray()) {
        $secure.AppendChar($character)
    }
    $secure.MakeReadOnly()
    $cache[$key] = [pscustomobject]@{
        Token     = $secure
        ExpiresAt = [datetime]::UtcNow.AddSeconds($lifetime - 60)
    }
    return $secure
}
