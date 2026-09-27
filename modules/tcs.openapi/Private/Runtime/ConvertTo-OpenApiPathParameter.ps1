function ConvertTo-OpenApiPathParameter {
    <#
    .SYNOPSIS
        Serialises a path parameter value with the simple, label or matrix style (percent-encoded, ready to put in the path).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [ValidateSet('simple', 'label', 'matrix')]
        [string]$Style = 'simple',

        [Parameter()]
        [switch]$Explode
    )

    $shape = Get-OpenApiValueShape -Value $Value
    $encodedName = ConvertTo-OpenApiUriEncoded -Value $Name
    $items = New-Object System.Collections.Generic.List[string]
    $pairs = New-Object System.Collections.Generic.List[object]
    if ($shape -eq 'Scalar') {
        $items.Add((ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $Value)))
    }
    elseif ($shape -eq 'Array') {
        foreach ($item in $Value) {
            $items.Add((ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $item)))
        }
    }
    elseif ($shape -eq 'Object') {
        foreach ($pair in (ConvertTo-OpenApiPropertyList -InputObject $Value)) {
            $pairs.Add(@((ConvertTo-OpenApiUriEncoded -Value $pair.Name), (ConvertTo-OpenApiUriEncoded -Value (ConvertTo-OpenApiScalarString -Value $pair.Value))))
        }
    }

    switch ($Style) {
        'simple' {
            if ($shape -eq 'Object') {
                if ($Explode) {
                    return (($pairs | ForEach-Object -Process { $_[0] + '=' + $_[1] }) -join ',')
                }
                return (($pairs | ForEach-Object -Process { $_[0] + ',' + $_[1] }) -join ',')
            }
            return ($items -join ',')
        }
        'label' {
            if ($shape -eq 'Object') {
                if ($Explode) {
                    return '.' + (($pairs | ForEach-Object -Process { $_[0] + '=' + $_[1] }) -join '.')
                }
                return '.' + (($pairs | ForEach-Object -Process { $_[0] + '.' + $_[1] }) -join '.')
            }
            return '.' + ($items -join '.')
        }
        'matrix' {
            if ($shape -eq 'Empty') {
                return ';' + $encodedName
            }
            if ($shape -eq 'Object') {
                if ($Explode) {
                    return ';' + (($pairs | ForEach-Object -Process { $_[0] + '=' + $_[1] }) -join ';')
                }
                return ';' + $encodedName + '=' + (($pairs | ForEach-Object -Process { $_[0] + ',' + $_[1] }) -join ',')
            }
            if ($shape -eq 'Array' -and $Explode) {
                return (($items | ForEach-Object -Process { ';' + $encodedName + '=' + $_ }) -join '')
            }
            return ';' + $encodedName + '=' + ($items -join ',')
        }
    }
}
