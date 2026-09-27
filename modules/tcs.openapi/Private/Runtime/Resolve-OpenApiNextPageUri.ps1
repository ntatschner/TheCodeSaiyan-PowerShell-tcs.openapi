function Resolve-OpenApiNextPageUri {
    <#
    .SYNOPSIS
        Resolves a next-page link against the current URL and returns it only when it points to the same scheme, host and port as the first request.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Link,

        [Parameter(Mandatory)]
        [string]$CurrentUri,

        [Parameter(Mandatory)]
        [string]$OriginUri
    )

    if ([string]::IsNullOrWhiteSpace($Link)) {
        return $null
    }
    $base = [uri]$CurrentUri
    $resolved = $null
    if (-not [uri]::TryCreate($base, $Link.Trim(), [ref]$resolved)) {
        Write-Warning -Message "Paging stopped: the next-page link '$Link' is not a valid URL."
        return $null
    }
    $origin = [uri]$OriginUri
    if ($resolved.Scheme -ne $origin.Scheme -or $resolved.Host -ne $origin.Host -or $resolved.Port -ne $origin.Port) {
        Write-Warning -Message "Paging stopped: the next-page link points to another host ($($resolved.Scheme)://$($resolved.Authority)); only links to $($origin.Scheme)://$($origin.Authority) are followed."
        return $null
    }
    return $resolved.AbsoluteUri
}
