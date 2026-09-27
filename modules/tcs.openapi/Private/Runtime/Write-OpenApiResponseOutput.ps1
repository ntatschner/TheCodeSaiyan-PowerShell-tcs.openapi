function Write-OpenApiResponseOutput {
    <#
    .SYNOPSIS
        Writes the objects of a parsed JSON response: array items one by one, the page's items for pageable operations, each with the response PSTypeName.
    .DESCRIPTION
        -ItemsProperty (a page's items) wins over -UnwrapProperty. -UnwrapProperty writes the value of that
        property of a response object instead of the object (its items one by one when it is an array); a
        response without the property is written whole.
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
        [string]$ItemsProperty,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$TypeName,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$UnwrapProperty
    )

    if ($null -eq $InputObject) {
        return
    }
    $value = $InputObject
    $property = $null
    if ($InputObject -isnot [array]) {
        if (-not [string]::IsNullOrEmpty($ItemsProperty) -and (Test-OpenApiMember -InputObject $InputObject -Name $ItemsProperty)) {
            $property = $ItemsProperty
        }
        elseif (-not [string]::IsNullOrEmpty($UnwrapProperty) -and (Test-OpenApiMember -InputObject $InputObject -Name $UnwrapProperty)) {
            $property = $UnwrapProperty
        }
    }
    if ($null -ne $property) {
        $value = Get-OpenApiMember -InputObject $InputObject -Name $property
        if ($null -eq $value) {
            return
        }
        if ($value -isnot [array]) {
            $value = @(, $value)
        }
    }
    if ($value -is [array]) {
        foreach ($item in $value) {
            Add-OpenApiTypeName -InputObject $item -TypeName $TypeName
        }
        return
    }
    Add-OpenApiTypeName -InputObject $value -TypeName $TypeName
}
