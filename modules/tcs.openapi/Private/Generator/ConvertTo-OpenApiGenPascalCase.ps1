function ConvertTo-OpenApiGenPascalCase {
    <#
    .SYNOPSIS
        Joins words (or splits a string into words first) into a PascalCase identifier made only of
        the characters A-Z, a-z and 0-9.

    .DESCRIPTION
        Each word gets a capital first letter and lower-case rest ('ID' -> 'Id', 'XML' -> 'Xml').
        Accents are removed (an accented 'A' becomes 'A') and any other character outside A-Z/0-9 is dropped.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Words')]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Word,

        [Parameter(Mandatory = $true, ParameterSetName = 'Value')]
        [AllowEmptyString()]
        [string]$Value
    )

    if ($PSCmdlet.ParameterSetName -eq 'Value') {
        $Word = Split-OpenApiGenWord -Value $Value
    }
    $builder = New-Object -TypeName System.Text.StringBuilder
    foreach ($item in $Word) {
        if ([string]::IsNullOrEmpty($item)) {
            continue
        }
        # Remove accents: decompose, then drop the combining marks
        $decomposed = $item.Normalize([System.Text.NormalizationForm]::FormD)
        $ascii = [regex]::Replace($decomposed, '[^A-Za-z0-9]', '')
        if ($ascii.Length -eq 0) {
            continue
        }
        [void]$builder.Append($ascii.Substring(0, 1).ToUpperInvariant())
        [void]$builder.Append($ascii.Substring(1).ToLowerInvariant())
    }
    return $builder.ToString()
}
