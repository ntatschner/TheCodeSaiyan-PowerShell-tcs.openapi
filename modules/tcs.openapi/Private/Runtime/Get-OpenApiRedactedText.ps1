function Get-OpenApiRedactedText {
    <#
    .SYNOPSIS
        Replaces secret values in a JSON or form-urlencoded body (properties named like password, secret, token, apiKey, client_secret) with ********.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrEmpty($Text)) {
        return $Text
    }
    $names = '[^"]*?(?:password|passwd|secret|token|api[-_]?key|client_secret|signature|credential)[^"]*'
    # JSON: "name": "value" | number | true/false/null
    $jsonPattern = '(?i)("' + $names + '"\s*:\s*)("(?:[^"\\]|\\.)*"|-?\d[\d.eE+-]*|true|false|null)'
    $redacted = [regex]::Replace($Text, $jsonPattern, '$1"********"')
    # Form-urlencoded: name=value pairs
    $formPattern = '(?i)((?:^|&)[^=&\s"]*?(?:password|passwd|secret|token|api[-_]?key|apikey|client_secret|signature|credential)[^=&\s"]*=)[^&]*'
    return [regex]::Replace($redacted, $formPattern, '$1********')
}
