function Split-OpenApiGenWord {
    <#
    .SYNOPSIS
        Splits an identifier (camelCase, PascalCase, snake_case, kebab-case, dotted, spaced or with
        punctuation such as '$filter' or 'page[size]') into words.

    .DESCRIPTION
        Boundaries: any character that is not a letter or digit; lower -> upper ('petId'); the last
        capital of an acronym before a capitalised word ('XMLHttp' -> 'XML', 'Http'); digit -> upper
        ('v2Beta' -> 'v2', 'Beta'). Digits stay with the word before them. Returns nothing for
        text without letters or digits. Words are written to the pipeline:
        wrap the call in @() for an array.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return
    }
    $pattern = '[^\p{L}\p{Nd}]+|(?<=\p{Ll})(?=\p{Lu})|(?<=\p{Lu})(?=\p{Lu}\p{Ll})|(?<=\p{Nd})(?=\p{Lu})'
    [regex]::Split($Value, $pattern) | Where-Object -FilterScript { $_ -ne '' }
}
