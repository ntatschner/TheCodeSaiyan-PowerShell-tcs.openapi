function ConvertTo-OpenApiRawNode {
    <#
    .SYNOPSIS
        Converts parsed JSON/YAML into the raw tree: case-sensitive ordered dictionaries, object[] and scalars.
    .DESCRIPTION
        Accepts System.Text.Json JsonElement values, PSCustomObject (ConvertFrom-Json), any IDictionary
        (JavaScriptSerializer, powershell-yaml) and lists. Keys are converted to strings and kept with an
        ordinal comparer, so keys that differ only in case stay distinct. DateTime values (produced by some
        parsers for date-like strings) are turned back into ISO 8601 strings. Arrays are returned wrapped so
        callers receive them unrolled only once.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return $null
    }
    if ($InputObject.GetType().FullName -eq 'System.Text.Json.JsonElement') {
        switch ($InputObject.ValueKind.ToString()) {
            'Object' {
                $map = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
                foreach ($property in $InputObject.EnumerateObject()) {
                    $map[$property.Name] = ConvertTo-OpenApiRawNode -InputObject $property.Value
                }
                return $map
            }
            'Array' {
                $list = [System.Collections.Generic.List[object]]::new()
                foreach ($element in $InputObject.EnumerateArray()) {
                    $list.Add((ConvertTo-OpenApiRawNode -InputObject $element))
                }
                return , $list.ToArray()
            }
            'String' {
                return $InputObject.GetString()
            }
            'Number' {
                $long = [long]0
                if ($InputObject.TryGetInt64([ref]$long)) {
                    if ($long -ge [int]::MinValue -and $long -le [int]::MaxValue) {
                        return [int]$long
                    }
                    return $long
                }
                return $InputObject.GetDouble()
            }
            'True' {
                return $true
            }
            'False' {
                return $false
            }
            default {
                return $null
            }
        }
    }

    if ($InputObject -is [datetime] -or $InputObject -is [System.DateTimeOffset]) {
        return $InputObject.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    if ($InputObject -is [string] -or $InputObject -is [ValueType]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $map = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($entry in $InputObject.GetEnumerator()) {
            $map[[string]$entry.Key] = ConvertTo-OpenApiRawNode -InputObject $entry.Value
        }
        return $map
    }

    if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
        $map = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($property in $InputObject.PSObject.Properties) {
            $map[$property.Name] = ConvertTo-OpenApiRawNode -InputObject $property.Value
        }
        return $map
    }

    if ($InputObject -is [System.Collections.IEnumerable]) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($element in $InputObject) {
            $list.Add((ConvertTo-OpenApiRawNode -InputObject $element))
        }
        return , $list.ToArray()
    }

    return $InputObject
}
