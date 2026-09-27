function Get-OpenApiMediaTypeKind {
    <#
    .SYNOPSIS
        Classifies a media type as Json, Form, Multipart, Text or Binary.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ContentType
    )

    if ([string]::IsNullOrWhiteSpace($ContentType)) {
        return 'Binary'
    }
    $mediaType = $ContentType.Split(';')[0].Trim().ToLowerInvariant()
    if ($mediaType -eq 'application/json' -or $mediaType.EndsWith('+json') -or $mediaType -eq 'text/json') {
        return 'Json'
    }
    if ($mediaType -eq 'application/x-www-form-urlencoded') {
        return 'Form'
    }
    if ($mediaType.StartsWith('multipart/')) {
        return 'Multipart'
    }
    if ($mediaType.StartsWith('text/') -or $mediaType -eq 'application/xml' -or $mediaType.EndsWith('+xml') -or $mediaType -eq 'application/javascript' -or $mediaType -eq 'application/x-yaml' -or $mediaType -eq 'application/yaml') {
        return 'Text'
    }
    return 'Binary'
}
