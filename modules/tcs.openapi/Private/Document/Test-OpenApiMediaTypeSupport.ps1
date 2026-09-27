function Test-OpenApiMediaTypeSupport {
    <#
    .SYNOPSIS
        Tests whether the runtime can serialise a request body of the given media type.
    .DESCRIPTION
        Supported: JSON (application/json, */*+json, */json), application/x-www-form-urlencoded,
        multipart/form-data, text/*, application/octet-stream, */*, media types without a schema, and
        binary schemas (type string with format binary or byte). Anything else (for example application/xml
        with an object schema) is sent as a raw string or bytes.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$ContentType,

        [AllowNull()]
        [object]$Schema
    )

    $mediaType = $ContentType.Split(';')[0].Trim().ToLowerInvariant()
    if ($mediaType -match '^[^/]+/([^/]+\+)?json$') {
        return $true
    }
    if ($mediaType -in @('application/x-www-form-urlencoded', 'multipart/form-data', 'application/octet-stream', '*/*') -or $mediaType.StartsWith('text/')) {
        return $true
    }
    if ($null -eq $Schema) {
        return $true
    }
    if ($Schema.Type -eq 'string' -and ($Schema.Format -eq 'binary' -or $Schema.Format -eq 'byte')) {
        return $true
    }
    return $false
}
