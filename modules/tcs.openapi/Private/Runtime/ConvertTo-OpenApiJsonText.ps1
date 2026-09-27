function ConvertTo-OpenApiJsonText {
    <#
    .SYNOPSIS
        Serialises a value as compact JSON (depth 64), keeping explicit nulls and single-item arrays.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return 'null'
    }
    $ready = ConvertTo-OpenApiJsonReady -InputObject $InputObject
    return (ConvertTo-Json -InputObject $ready -Depth 64 -Compress)
}
