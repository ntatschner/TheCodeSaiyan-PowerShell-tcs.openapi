function Add-OpenApiTypeName {
    <#
    .SYNOPSIS
        Inserts a PSTypeName at the front of an object's type names (PSCustomObject values only) and returns the object.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$TypeName
    )

    if (-not [string]::IsNullOrEmpty($TypeName) -and $InputObject -is [System.Management.Automation.PSCustomObject]) {
        if ($InputObject.PSObject.TypeNames[0] -ne $TypeName) {
            $InputObject.PSObject.TypeNames.Insert(0, $TypeName)
        }
    }
    return , $InputObject
}
