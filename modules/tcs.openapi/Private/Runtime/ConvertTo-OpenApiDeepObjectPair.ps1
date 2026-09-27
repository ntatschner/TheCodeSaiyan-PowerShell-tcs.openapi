function ConvertTo-OpenApiDeepObjectPair {
    <#
    .SYNOPSIS
        Flattens an object into deepObject query pairs (name[key]=value, nested as name[a][b]=value, arrays repeated).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Prefix,

        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [switch]$AllowReserved
    )

    $shape = Get-OpenApiValueShape -Value $Value
    if ($shape -eq 'Object') {
        foreach ($pair in (ConvertTo-OpenApiPropertyList -InputObject $Value)) {
            $key = $Prefix + '[' + (ConvertTo-OpenApiUriEncoded -Value $pair.Name) + ']'
            ConvertTo-OpenApiDeepObjectPair -Prefix $key -Value $pair.Value -AllowReserved:$AllowReserved
        }
        return
    }
    if ($shape -eq 'Array') {
        foreach ($item in $Value) {
            $Prefix + '=' + (ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $item) -AllowReserved:$AllowReserved)
        }
        return
    }
    $Prefix + '=' + (ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $Value) -AllowReserved:$AllowReserved)
}
