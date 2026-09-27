function ConvertTo-OpenApiQueryParameter {
    <#
    .SYNOPSIS
        Serialises a query parameter with the form, spaceDelimited, pipeDelimited or deepObject style; returns encoded name=value pairs.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [ValidateSet('form', 'spaceDelimited', 'pipeDelimited', 'deepObject')]
        [string]$Style = 'form',

        [Parameter()]
        [switch]$Explode,

        [Parameter()]
        [switch]$AllowReserved
    )

    $shape = Get-OpenApiValueShape -Value $Value
    $encodedName = ConvertTo-OpenApiUriEncoded -Value $Name
    $result = New-Object System.Collections.Generic.List[string]

    if ($Style -eq 'deepObject' -and $shape -eq 'Object') {
        foreach ($pair in (ConvertTo-OpenApiDeepObjectPair -Prefix $encodedName -Value $Value -AllowReserved:$AllowReserved)) {
            $result.Add($pair)
        }
        return , $result.ToArray()
    }

    $items = New-Object System.Collections.Generic.List[string]
    if ($shape -eq 'Scalar') {
        $items.Add((ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $Value) -AllowReserved:$AllowReserved))
    }
    elseif ($shape -eq 'Array') {
        foreach ($item in $Value) {
            $items.Add((ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $item) -AllowReserved:$AllowReserved))
        }
    }
    elseif ($shape -eq 'Object') {
        foreach ($pair in (ConvertTo-OpenApiPropertyList -InputObject $Value)) {
            $key = ConvertTo-OpenApiUriEncoded -Value $pair.Name -AllowReserved:$AllowReserved
            $text = ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $pair.Value) -AllowReserved:$AllowReserved
            if ($Explode) {
                # Exploded objects become one name=value pair per property
                $result.Add($key + '=' + $text)
            }
            else {
                $items.Add($key)
                $items.Add($text)
            }
        }
        if ($Explode) {
            return , $result.ToArray()
        }
    }

    if ($shape -eq 'Empty') {
        $result.Add($encodedName + '=')
        return , $result.ToArray()
    }
    if ($shape -eq 'Array' -and $Explode) {
        foreach ($item in $items) {
            $result.Add($encodedName + '=' + $item)
        }
        return , $result.ToArray()
    }

    $delimiter = ','
    if ($Style -eq 'spaceDelimited') {
        $delimiter = '%20'
    }
    elseif ($Style -eq 'pipeDelimited') {
        $delimiter = '|'
    }
    $result.Add($encodedName + '=' + ($items -join $delimiter))
    return , $result.ToArray()
}
