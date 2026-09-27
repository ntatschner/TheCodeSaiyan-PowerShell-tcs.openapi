function ConvertTo-OpenApiGenJson {
    <#
    .SYNOPSIS
        Serialises an object to JSON text that is identical on every machine and PowerShell edition.

    .DESCRIPTION
        ConvertTo-Json formats differently on Windows PowerShell 5.1 and PowerShell 7, so the generator
        uses this writer instead: two-space indentation, LF line endings, invariant number formats,
        non-ASCII characters escaped as \uXXXX (the output is plain ASCII), ordered dictionaries and
        PSCustomObjects in their own order and other dictionaries sorted by key (ordinal). A reference
        cycle is written as { "RefName": ..., "Recursive": true } (or null) instead of recursing.
        -Compress writes everything on one line without spaces. -SkipEmpty leaves out map entries whose
        value is null, an empty string, an empty array or an empty map.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter()]
        [switch]$Compress,

        [Parameter()]
        [switch]$SkipEmpty
    )

    $builder = New-Object -TypeName System.Text.StringBuilder
    $newLine = "`n"
    $indentUnit = '  '
    $colon = ': '
    if ($Compress) {
        $newLine = ''
        $indentUnit = ''
        $colon = ':'
    }
    $isEmpty = {
        param($Item)
        if ($null -eq $Item) {
            return $true
        }
        if ($Item -is [string]) {
            return $Item.Length -eq 0
        }
        if ($Item -is [System.Collections.IDictionary]) {
            return $Item.Count -eq 0
        }
        if ($Item -is [System.Management.Automation.PSCustomObject]) {
            return @($Item.PSObject.Properties).Count -eq 0
        }
        if ($Item -is [System.Collections.ICollection]) {
            return $Item.Count -eq 0
        }
        return $false
    }
    $ancestors = New-Object -TypeName System.Collections.ArrayList
    $escapeEvaluator = [System.Text.RegularExpressions.MatchEvaluator] {
        param($Match)

        switch ([int][char]$Match.Value) {
            8 { return '\b' }
            9 { return '\t' }
            10 { return '\n' }
            12 { return '\f' }
            13 { return '\r' }
            34 { return '\"' }
            92 { return '\\' }
        }
        return '\u' + ([int][char]$Match.Value).ToString('x4', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    $writer = {
        param($Value, [int]$Depth)

        $indent = $newLine + ($indentUnit * ($Depth + 1))
        $closeIndent = $newLine + ($indentUnit * $Depth)
        if ($null -eq $Value) {
            [void]$builder.Append('null')
            return
        }
        if ($Value -is [System.Management.Automation.SwitchParameter]) {
            $Value = $Value.IsPresent
        }
        if ($Value -is [bool]) {
            [void]$builder.Append($(if ($Value) { 'true' } else { 'false' }))
            return
        }
        if ($Value -is [string] -or $Value -is [char] -or $Value -is [guid] -or $Value -is [uri] -or $Value -is [enum] -or $Value -is [version]) {
            $escaped = [regex]::Replace([string]$Value, '["\\\u0000-\u001F\u007F-\uFFFF]', $escapeEvaluator)
            [void]$builder.Append('"' + $escaped + '"')
            return
        }
        if ($Value -is [datetime]) {
            [void]$builder.Append('"' + $Value.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture) + '"')
            return
        }
        if ($Value -is [double] -or $Value -is [single]) {
            if ([double]::IsNaN($Value) -or [double]::IsInfinity($Value)) {
                [void]$builder.Append('null')
            }
            else {
                [void]$builder.Append(([double]$Value).ToString('R', [System.Globalization.CultureInfo]::InvariantCulture))
            }
            return
        }
        if ($Value -is [byte] -or $Value -is [sbyte] -or $Value -is [int16] -or $Value -is [uint16] -or $Value -is [int] -or $Value -is [uint32] -or $Value -is [long] -or $Value -is [uint64] -or $Value -is [decimal] -or $Value.GetType().FullName -eq 'System.Numerics.BigInteger') {
            [void]$builder.Append(([System.IFormattable]$Value).ToString($null, [System.Globalization.CultureInfo]::InvariantCulture))
            return
        }

        # Containers: stop at reference cycles
        foreach ($ancestor in $ancestors) {
            if ([object]::ReferenceEquals($ancestor, $Value)) {
                $refName = $null
                if (-not ($Value -is [System.Collections.IEnumerable]) -or $Value -is [System.Collections.IDictionary]) {
                    $refName = Get-OpenApiGenMapValue -Map $Value -Key 'RefName'
                }
                if ($null -eq $refName) {
                    [void]$builder.Append('null')
                }
                else {
                    & $writer ([ordered]@{ RefName = $refName; Recursive = $true }) $Depth
                }
                return
            }
        }
        [void]$ancestors.Add($Value)
        try {
            $isMap = ($Value -is [System.Collections.IDictionary]) -or ($Value -is [System.Management.Automation.PSCustomObject])
            if ($isMap) {
                $entries = @(Get-OpenApiGenMapEntry -Map $Value)
                if ($SkipEmpty) {
                    $entries = @($entries | Where-Object -FilterScript { -not (& $isEmpty $_.Value) })
                }
                if ($entries.Count -eq 0) {
                    [void]$builder.Append('{}')
                    return
                }
                [void]$builder.Append('{')
                for ($i = 0; $i -lt $entries.Count; $i++) {
                    [void]$builder.Append($indent)
                    & $writer ([string]$entries[$i].Key) 0
                    [void]$builder.Append($colon)
                    & $writer $entries[$i].Value ($Depth + 1)
                    if ($i -lt $entries.Count - 1) {
                        [void]$builder.Append(',')
                    }
                }
                [void]$builder.Append($closeIndent + '}')
                return
            }
            if ($Value -is [System.Collections.IEnumerable]) {
                $items = @(foreach ($item in $Value) { , $item })
                if ($items.Count -eq 0) {
                    [void]$builder.Append('[]')
                    return
                }
                [void]$builder.Append('[')
                for ($i = 0; $i -lt $items.Count; $i++) {
                    [void]$builder.Append($indent)
                    & $writer $items[$i] ($Depth + 1)
                    if ($i -lt $items.Count - 1) {
                        [void]$builder.Append(',')
                    }
                }
                [void]$builder.Append($closeIndent + ']')
                return
            }
            # Any other object: its public properties, in declaration order
            $objectMap = [ordered]@{}
            foreach ($property in $Value.PSObject.Properties) {
                if ($property.MemberType -match 'Property') {
                    $objectMap[$property.Name] = $property.Value
                }
            }
            & $writer $objectMap $Depth
        }
        finally {
            [void]$ancestors.RemoveAt($ancestors.Count - 1)
        }
    }

    & $writer $InputObject 0
    return $builder.ToString()
}
