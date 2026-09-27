function Expand-OpenApiGenTemplate {
    <#
    .SYNOPSIS
        Replaces the {{Name}} placeholders of a template with values.

    .DESCRIPTION
        Every placeholder must have a value (a missing value is an error, so a template change cannot
        silently produce broken code). A line that holds only a placeholder whose value is empty is
        removed. Values are inserted as they are. The result uses LF line endings.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Template,

        [Parameter(Mandatory = $true)]
        [hashtable]$Value
    )

    $text = $Template.Replace("`r`n", "`n")
    $missing = @([regex]::Matches($text, '\{\{([A-Za-z0-9]+)\}\}') | ForEach-Object -Process { $_.Groups[1].Value } |
            Where-Object -FilterScript { -not $Value.ContainsKey($_) } | Select-Object -Unique)
    if ($missing.Count -gt 0) {
        throw "The template has placeholders without a value: $($missing -join ', ')."
    }
    # Remove lines that hold only an empty placeholder
    $text = [regex]::Replace($text, '(?m)^[ \t]*\{\{([A-Za-z0-9]+)\}\}[ \t]*\n', {
            param($Match)
            if ([string]::IsNullOrEmpty([string]$Value[$Match.Groups[1].Value])) {
                return ''
            }
            return $Match.Value
        })
    return [regex]::Replace($text, '\{\{([A-Za-z0-9]+)\}\}', {
            param($Match)
            return [string]$Value[$Match.Groups[1].Value]
        })
}
