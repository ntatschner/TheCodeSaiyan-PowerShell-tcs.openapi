function Get-OpenApiGenMediaKind {
    <#
    .SYNOPSIS
        Classifies a media type as 'json', 'form', 'multipart', 'text' or 'binary'.

    .DESCRIPTION
        json: application/json, text/json, */*+json and */* (any type). form: application/x-www-form-urlencoded.
        multipart: multipart/*. text: text/*, application/xml and */*+xml. binary: everything else
        (application/octet-stream, images, PDF, archives ...), and any media type whose schema is a
        string with format 'binary'. Parameters such as '; charset=utf-8' are ignored.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ContentType,

        [Parameter()]
        [AllowNull()]
        [object]$Schema
    )

    $type = ([string]$ContentType).Split(';')[0].Trim().ToLowerInvariant()
    if ($null -ne $Schema -and $Schema.Type -eq 'string' -and $Schema.Format -eq 'binary' -and $type -notmatch '^multipart/' -and $type -ne 'application/x-www-form-urlencoded') {
        return 'binary'
    }
    if ($type -eq 'application/json' -or $type -eq 'text/json' -or $type -eq '*/*' -or $type -match '^[^/]+/[^/]*\+json$') {
        return 'json'
    }
    if ($type -eq 'application/x-www-form-urlencoded') {
        return 'form'
    }
    if ($type -match '^multipart/') {
        return 'multipart'
    }
    if ($type -match '^text/' -or $type -eq 'application/xml' -or $type -match '^[^/]+/[^/]*\+xml$') {
        return 'text'
    }
    return 'binary'
}
