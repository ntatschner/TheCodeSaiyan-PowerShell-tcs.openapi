function Get-OpenApiRetryPolicy {
    <#
    .SYNOPSIS
        Returns the retry settings for a request: status codes to retry by method (idempotent vs POST/PATCH), delays and retry count.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter()]
        [int]$MaxRetries = 3
    )

    $idempotent = @('GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE', 'TRACE') -contains $Method.ToUpperInvariant()
    $statusCodes = @(429, 503)
    if ($idempotent) {
        $statusCodes = @(408, 429, 500, 502, 503, 504)
    }
    return [pscustomobject]@{
        StatusCodes            = $statusCodes
        MaxRetries             = [Math]::Max(0, $MaxRetries)
        DelaySeconds           = 1
        BackoffMultiplier      = 2
        MaxDelaySeconds        = 60
        JitterPercent          = 20
        RetryConnectionFailure = $idempotent
    }
}
