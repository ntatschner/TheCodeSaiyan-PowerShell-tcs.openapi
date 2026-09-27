function ConvertTo-OpenApiJsonReady {
    <#
    .SYNOPSIS
        Copies a value into plain dictionaries and arrays that ConvertTo-Json writes the same on 5.1 and 7 (dates as ISO 8601, switches as booleans, nulls kept).
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter()]
        [int]$Depth = 0
    )

    if ($null -eq $InputObject) {
        return $null
    }
    if ($Depth -gt 64) {
        throw 'The body is nested more than 64 levels deep.'
    }
    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    if ($InputObject -is [System.Management.Automation.SwitchParameter]) {
        return $InputObject.IsPresent
    }
    if ($InputObject -is [datetime] -or $InputObject -is [System.DateTimeOffset]) {
        return $InputObject.ToString('o', $invariant)
    }
    if ($InputObject -is [enum]) {
        return $InputObject.ToString()
    }
    if ($InputObject -is [string] -or $InputObject -is [char] -or $InputObject -is [bool] -or $InputObject -is [System.ValueType]) {
        return $InputObject
    }
    if ($InputObject -is [guid] -or $InputObject -is [uri] -or $InputObject -is [version]) {
        return $InputObject.ToString()
    }
    if ($InputObject -is [System.Collections.IDictionary] -or $InputObject -is [System.Management.Automation.PSCustomObject]) {
        $copy = [ordered]@{}
        foreach ($pair in (ConvertTo-OpenApiPropertyList -InputObject $InputObject)) {
            $copy[$pair.Name] = ConvertTo-OpenApiJsonReady -InputObject $pair.Value -Depth ($Depth + 1)
        }
        return $copy
    }
    if ($InputObject -is [System.Collections.IEnumerable]) {
        $items = New-Object System.Collections.Generic.List[object]
        foreach ($item in $InputObject) {
            $items.Add((ConvertTo-OpenApiJsonReady -InputObject $item -Depth ($Depth + 1)))
        }
        return , $items.ToArray()
    }
    return $InputObject
}
