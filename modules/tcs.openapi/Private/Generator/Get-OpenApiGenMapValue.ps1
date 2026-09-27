function Get-OpenApiGenMapValue {
    <#
    .SYNOPSIS
        Returns the value stored under a key in a document-model map (dictionary or PSCustomObject), or $null.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Map,

        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    if ($null -eq $Map) {
        return $null
    }
    if ($Map -is [System.Collections.IDictionary]) {
        if ($Map.Contains($Key)) {
            return , $Map[$Key]
        }
        return $null
    }
    $property = $Map.PSObject.Properties[$Key]
    if ($null -ne $property) {
        return , $property.Value
    }
    return $null
}
