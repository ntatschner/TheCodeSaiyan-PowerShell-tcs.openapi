function Test-OpenApiMember {
    <#
    .SYNOPSIS
        Tests whether a hashtable/dictionary has a key, or an object has a property, with the given name.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $false
    }
    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            if ([string]$key -eq $Name) {
                return $true
            }
        }
        return $false
    }
    return ($null -ne $InputObject.PSObject.Properties[$Name])
}
