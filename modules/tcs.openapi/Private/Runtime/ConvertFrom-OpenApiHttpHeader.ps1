function ConvertFrom-OpenApiHttpHeader {
    <#
    .SYNOPSIS
        Converts the response and content headers of an HttpResponseMessage to a case-insensitive hashtable (string, or string[] for repeated headers).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Net.Http.HttpResponseMessage]$Response
    )

    $headers = @{}
    $collections = @($Response.Headers)
    if ($null -ne $Response.Content) {
        $collections += , $Response.Content.Headers
    }
    foreach ($collection in $collections) {
        foreach ($pair in $collection) {
            $values = @($pair.Value)
            if ($headers.ContainsKey($pair.Key)) {
                $values = @($headers[$pair.Key]) + $values
            }
            if ($values.Count -eq 1) {
                $headers[$pair.Key] = [string]$values[0]
            }
            else {
                $headers[$pair.Key] = [string[]]$values
            }
        }
    }
    return $headers
}
