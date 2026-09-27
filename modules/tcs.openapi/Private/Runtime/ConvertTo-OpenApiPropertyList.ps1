function ConvertTo-OpenApiPropertyList {
    <#
    .SYNOPSIS
        Returns the name/value pairs of a dictionary or PSCustomObject, in order, as objects with Name and Value.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            [pscustomobject]@{ Name = [string]$key; Value = $InputObject[$key] }
        }
        return
    }
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -eq 'NoteProperty' -or $property.MemberType -eq 'Property') {
            [pscustomobject]@{ Name = $property.Name; Value = $property.Value }
        }
    }
}
