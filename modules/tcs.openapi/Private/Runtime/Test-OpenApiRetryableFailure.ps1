function Test-OpenApiRetryableFailure {
    <#
    .SYNOPSIS
        Decides whether a failed attempt is retried: HTTP responses always (status filtering is done by Invoke-WithRetry), transport failures only for idempotent methods.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [object]$ErrorRecord,

        [Parameter(Mandatory)]
        [pscustomobject]$Policy
    )

    $exception = $ErrorRecord
    if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
        $exception = $ErrorRecord.Exception
    }
    if ($null -ne $exception.PSObject.Properties['TcsOpenApiResponse']) {
        return $true
    }
    $current = $exception
    while ($null -ne $current) {
        if ($current -is [System.Net.Http.HttpRequestException] -or $current -is [System.TimeoutException] -or $current -is [System.IO.IOException] -or $current -is [System.Net.Sockets.SocketException]) {
            return [bool]$Policy.RetryConnectionFailure
        }
        $current = $current.InnerException
    }
    return $false
}
