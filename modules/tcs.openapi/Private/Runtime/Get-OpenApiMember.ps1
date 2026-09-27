function Get-OpenApiMember {
    <#
    .SYNOPSIS
        Returns a named value from a hashtable/dictionary or an object property, or $null when it is missing.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return , $InputObject[$Name]
        }
        # Hashtables from JSON may differ in case; dictionaries such as [ordered] are case-sensitive
        foreach ($key in $InputObject.Keys) {
            if ([string]$key -eq $Name) {
                return , $InputObject[$key]
            }
        }
        return $null
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return , $property.Value
    }
    return $null
}
