function Add-OpenApiQueryString {
    <#
    .SYNOPSIS
        Appends encoded name=value pairs to a URL, with '?' or '&' as needed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Pair
    )

    $items = @($Pair | Where-Object -FilterScript { -not [string]::IsNullOrEmpty($_) })
    if ($items.Count -eq 0) {
        return $Uri
    }
    $fragment = ''
    $hashIndex = $Uri.IndexOf('#')
    if ($hashIndex -ge 0) {
        $fragment = $Uri.Substring($hashIndex)
        $Uri = $Uri.Substring(0, $hashIndex)
    }
    $separator = '?'
    if ($Uri.Contains('?')) {
        $separator = '&'
        if ($Uri.EndsWith('?') -or $Uri.EndsWith('&')) {
            $separator = ''
        }
    }
    return $Uri + $separator + ($items -join '&') + $fragment
}
