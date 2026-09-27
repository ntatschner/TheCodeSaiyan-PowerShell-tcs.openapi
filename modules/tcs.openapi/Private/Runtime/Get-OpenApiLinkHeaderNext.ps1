function Get-OpenApiLinkHeaderNext {
    <#
    .SYNOPSIS
        Returns the URL of the rel="next" entry of an RFC 8288 Link header, or $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$LinkHeader
    )

    foreach ($header in @($LinkHeader)) {
        if ([string]::IsNullOrEmpty($header)) {
            continue
        }
        foreach ($match in [regex]::Matches($header, '<([^>]*)>([^<]*)')) {
            $parameters = $match.Groups[2].Value
            if ($parameters -match '(?i)(^|;)\s*rel\s*=\s*"?([^";]*)"?') {
                $relations = $Matches[2].Trim().Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
                if ($relations -contains 'next') {
                    return $match.Groups[1].Value
                }
            }
        }
    }
    return $null
}
