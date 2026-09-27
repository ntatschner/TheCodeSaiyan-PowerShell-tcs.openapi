function ConvertTo-OpenApiGenLiteral {
    <#
    .SYNOPSIS
        Returns PowerShell source for a single-quoted string literal holding the given text.

    .DESCRIPTION
        Doubles every character PowerShell treats as a single quote (the ASCII quote and the
        typographic quotes U+2018 to U+201B), so any text from a document is safe to embed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($null -eq $Value) {
        $Value = ''
    }
    $escaped = [regex]::Replace($Value, '[''\u2018-\u201B]', '$0$0')
    return "'" + $escaped + "'"
}
