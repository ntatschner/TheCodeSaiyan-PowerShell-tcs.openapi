function Invoke-OpenApiHttpExchange {
    <#
    .SYNOPSIS
        Sends a request with authentication and retries (tcs.core Invoke-WithRetry), refreshing an OAuth2 token once on 401; returns the final response object.
    .DESCRIPTION
        The returned response may be any status code; callers decide what is an error. Transport failures that are not
        retried (or keep failing) are thrown.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [object]$Operation,

        [Parameter(Mandatory)]
        [System.Net.Http.HttpClient]$Client,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$Header,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Cookie,

        [Parameter()]
        [AllowNull()]
        [scriptblock]$ContentFactory,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$SensitiveName
    )

    $policy = Get-OpenApiRetryPolicy -Method $Method -MaxRetries $Context.MaxRetries
    $refreshed = $false
    $forceRefresh = $false
    while ($true) {
        $auth = Get-OpenApiAuthorization -Operation $Operation -Context $Context -Client $Client -ForceRefresh:$forceRefresh

        # Query credentials are added unless the URL (for example a next-page link) already has them
        $queryPairs = New-Object System.Collections.Generic.List[string]
        foreach ($pair in $auth.Query) {
            $name = $pair.Substring(0, $pair.IndexOf('='))
            if ($Uri -notmatch ('[?&]' + [regex]::Escape($name) + '=')) {
                $queryPairs.Add($pair)
            }
        }
        $requestUri = Add-OpenApiQueryString -Uri $Uri -Pair $queryPairs.ToArray()

        $requestHeaders = [ordered]@{}
        if ($null -ne $Header) {
            foreach ($key in $Header.Keys) {
                $requestHeaders[[string]$key] = $Header[$key]
            }
        }
        foreach ($key in $auth.Header.Keys) {
            $requestHeaders[$key] = $auth.Header[$key]
        }
        $allCookies = @(@($Cookie) + @($auth.Cookie) | Where-Object -FilterScript { -not [string]::IsNullOrEmpty($_) })
        if ($allCookies.Count -gt 0) {
            $requestHeaders['Cookie'] = $allCookies -join '; '
        }
        $names = @(@($SensitiveName) + @($auth.SensitiveName) | Where-Object -FilterScript { -not [string]::IsNullOrEmpty($_) })

        $attempt = {
            $response = Send-OpenApiHttpRequest -Client $Client -Method $Method -Uri $requestUri -Header $requestHeaders -ContentFactory $ContentFactory -SensitiveName $names
            if ($policy.StatusCodes -contains $response.StatusCode) {
                throw (Build-OpenApiRetryException -Response $response)
            }
            $response
        }
        $shouldRetry = {
            param($errorRecord)
            Test-OpenApiRetryableFailure -ErrorRecord $errorRecord -Policy $policy
        }
        $retryParameters = @{
            ScriptBlock       = $attempt
            MaxRetries        = $policy.MaxRetries
            DelaySeconds      = $policy.DelaySeconds
            BackoffMultiplier = $policy.BackoffMultiplier
            MaxDelaySeconds   = $policy.MaxDelaySeconds
            JitterPercent     = $policy.JitterPercent
            RetryOnStatusCode = $policy.StatusCodes
            ShouldRetry       = $shouldRetry
            ErrorAction       = 'Stop'
            Verbose           = ($VerbosePreference -ne 'SilentlyContinue')
        }
        try {
            $response = Invoke-WithRetry @retryParameters
        }
        catch {
            $failed = $_.Exception
            if ($null -ne $failed -and $null -ne $failed.PSObject.Properties['TcsOpenApiResponse']) {
                # Retries are used up: the last response is returned for the caller to report
                $response = $failed.TcsOpenApiResponse
            }
            else {
                throw
            }
        }

        if ($response.StatusCode -eq 401 -and $auth.UsesOAuth -and -not $refreshed) {
            Write-Verbose -Message 'The server answered 401 Unauthorized; requesting a new OAuth2 access token and trying once more.'
            $null = Read-OpenApiResponseBody -Response $response
            $refreshed = $true
            $forceRefresh = $true
            continue
        }
        return $response
    }
}
