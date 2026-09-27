function ConvertTo-OpenApiScalarString {
    <#
    .SYNOPSIS
        Converts a single value to the text sent on the wire: booleans as true/false, dates as ISO 8601 round-trip, numbers invariant, nested structures as JSON.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ''
    }
    if ($Value -is [System.Management.Automation.SwitchParameter]) {
        $Value = $Value.IsPresent
    }
    if ($Value -is [bool]) {
        if ($Value) {
            return 'true'
        }
        return 'false'
    }
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    if ($Value -is [datetime] -or $Value -is [System.DateTimeOffset]) {
        return $Value.ToString('o', $invariant)
    }
    if ($Value -is [enum]) {
        return $Value.ToString()
    }
    if ($Value -is [System.Collections.IDictionary] -or $Value -is [System.Management.Automation.PSCustomObject] -or ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])) {
        # Nested structures inside a styled parameter are sent as compact JSON
        return (ConvertTo-OpenApiJsonText -InputObject $Value)
    }
    if ($Value -is [System.IFormattable]) {
        return $Value.ToString($null, $invariant)
    }
    return [string]$Value
}
