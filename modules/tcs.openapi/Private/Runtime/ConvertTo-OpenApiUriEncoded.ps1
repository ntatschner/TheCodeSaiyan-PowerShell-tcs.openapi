function ConvertTo-OpenApiUriEncoded {
    <#
    .SYNOPSIS
        Percent-encodes text for a URI (RFC 3986): unreserved characters are kept, and reserved ones too with -AllowReserved.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter()]
        [switch]$AllowReserved
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return ''
    }
    $unreserved = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~'
    $reserved = ":/?#[]@!$&'()*+,;="
    $builder = New-Object System.Text.StringBuilder
    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $index = 0
    while ($index -lt $Value.Length) {
        $character = $Value[$index]
        if ($unreserved.IndexOf($character) -ge 0 -or ($AllowReserved -and $reserved.IndexOf($character) -ge 0)) {
            [void]$builder.Append($character)
            $index++
            continue
        }
        # Surrogate pairs are encoded together as one code point
        $length = 1
        if ([char]::IsHighSurrogate($character) -and ($index + 1) -lt $Value.Length -and [char]::IsLowSurrogate($Value[$index + 1])) {
            $length = 2
        }
        foreach ($byte in $utf8.GetBytes($Value.Substring($index, $length))) {
            [void]$builder.Append('%').Append($byte.ToString('X2', [System.Globalization.CultureInfo]::InvariantCulture))
        }
        $index += $length
    }
    return $builder.ToString()
}
