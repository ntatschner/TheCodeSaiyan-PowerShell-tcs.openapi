function ConvertTo-OpenApiFormBody {
    <#
    .SYNOPSIS
        Encodes a hashtable or object as application/x-www-form-urlencoded text (arrays repeat the name, nested values as JSON).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return ''
    }
    if ($InputObject -is [string]) {
        return $InputObject
    }
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach ($property in (ConvertTo-OpenApiPropertyList -InputObject $InputObject)) {
        $name = ConvertTo-OpenApiUriEncoded -Value $property.Name
        $shape = Get-OpenApiValueShape -Value $property.Value
        if ($shape -eq 'Array') {
            foreach ($item in $property.Value) {
                $pairs.Add($name + '=' + (ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $item)))
            }
        }
        else {
            $pairs.Add($name + '=' + (ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $property.Value)))
        }
    }
    return ($pairs -join '&')
}
