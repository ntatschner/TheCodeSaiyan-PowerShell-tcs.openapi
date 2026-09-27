function Write-OpenApiResponseOutput {
    <#
    .SYNOPSIS
        Writes the objects of a parsed JSON response: array items one by one, the page's items for pageable operations, each with the response PSTypeName.
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
        [string]$TypeName
    )

    if ($null -eq $InputObject) {
        return
    }
    $value = $InputObject
    if (-not [string]::IsNullOrEmpty($ItemsProperty) -and (Test-OpenApiMember -InputObject $InputObject -Name $ItemsProperty)) {
        $value = Get-OpenApiMember -InputObject $InputObject -Name $ItemsProperty
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
