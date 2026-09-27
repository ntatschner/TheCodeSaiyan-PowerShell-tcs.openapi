function ConvertTo-OpenApiHeaderParameter {
    <#
    .SYNOPSIS
        Serialises a header parameter value with the simple style (not percent-encoded).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [switch]$Explode
    )

    $shape = Get-OpenApiValueShape -Value $Value
    if ($shape -eq 'Empty') {
        return ''
    }
    if ($shape -eq 'Scalar') {
        return (ConvertTo-OpenApiScalarString -Value $Value)
    }
    if ($shape -eq 'Array') {
        return ((@($Value) | ForEach-Object -Process { ConvertTo-OpenApiScalarString -Value $_ }) -join ',')
    }
    $parts = foreach ($pair in (ConvertTo-OpenApiPropertyList -InputObject $Value)) {
        if ($Explode) {
            $pair.Name + '=' + (ConvertTo-OpenApiScalarString -Value $pair.Value)
        }
        else {
            $pair.Name
            ConvertTo-OpenApiScalarString -Value $pair.Value
        }
    }
    return (@($parts) -join ',')
}
