function Get-OpenApiValueShape {
    <#
    .SYNOPSIS
        Classifies a parameter value as Empty, Scalar, Array or Object for style serialisation.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return 'Empty'
    }
    if ($Value -is [string]) {
        if ($Value.Length -eq 0) {
            return 'Empty'
        }
        return 'Scalar'
    }
    if ($Value -is [System.Collections.IDictionary] -or $Value -is [System.Management.Automation.PSCustomObject]) {
        return 'Object'
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        if (@($Value).Count -eq 0) {
            return 'Empty'
        }
        return 'Array'
    }
    return 'Scalar'
}
