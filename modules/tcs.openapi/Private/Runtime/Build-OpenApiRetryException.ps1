function Build-OpenApiRetryException {
    <#
    .SYNOPSIS
        Wraps a retryable HTTP response in an exception that tcs.core Invoke-WithRetry understands (StatusCode and Retry-After through a Response property).
    #>
    [CmdletBinding()]
    [OutputType([System.Exception])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Response
    )

    $null = Read-OpenApiResponseBody -Response $Response
    $exception = New-Object System.Net.Http.HttpRequestException -ArgumentList "The request $($Response.Method) returned $($Response.StatusCode) $($Response.ReasonPhrase)."
    # Invoke-WithRetry reads Response.StatusCode and Response.Headers['Retry-After'] from the exception
    $httpResponse = [pscustomobject]@{
        StatusCode        = $Response.StatusCode
        StatusDescription = $Response.ReasonPhrase
        Headers           = $Response.Headers
    }
    Add-Member -InputObject $exception -NotePropertyName 'Response' -NotePropertyValue $httpResponse -Force
    Add-Member -InputObject $exception -NotePropertyName 'TcsOpenApiResponse' -NotePropertyValue $Response -Force
    return $exception
}
