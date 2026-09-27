function ConvertTo-OpenApiDeepObjectPair {
    <#
    .SYNOPSIS
        Flattens an object into deepObject query pairs (name%5Bkey%5D=value, i.e. name[key]=value with the brackets
        percent-encoded; nested as name[a][b]=value, arrays repeated).
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
            # The brackets are percent-encoded (RFC 3986 allows them unencoded only in the host); .NET Framework
            # would encode them anyway, so both editions send the same query
            $key = $Prefix + '%5B' + (ConvertTo-OpenApiUriEncoded -Value $pair.Name) + '%5D'
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
