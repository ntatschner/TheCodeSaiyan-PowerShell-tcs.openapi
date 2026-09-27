function ConvertTo-OpenApiSecurityRequirement {
    <#
    .SYNOPSIS
        Normalises a raw security requirement list into [ { schemeName: [scopes] } ].
    .DESCRIPTION
        An empty list stays empty (no authentication); an empty requirement {} stays an empty map
        (authentication optional). Names that are not defined security schemes give OA021 (Warning).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Requirement,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    $defined = $null
    if ($Context.Root['components'] -is [System.Collections.IDictionary]) {
        $defined = $Context.Root['components']['securitySchemes']
    }
    $list = [System.Collections.Generic.List[object]]::new()
    if ($Requirement -is [System.Collections.IList]) {
        $index = 0
        foreach ($item in $Requirement) {
            $map = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            if ($item -is [System.Collections.IDictionary]) {
                foreach ($name in @($item.Keys)) {
                    $scopes = [System.Collections.Generic.List[string]]::new()
                    foreach ($scope in @($item[$name])) {
                        if ($null -ne $scope) {
                            $scopes.Add([string]$scope)
                        }
                    }
                    $map[$name] = $scopes.ToArray()
                    if ($defined -isnot [System.Collections.IDictionary] -or -not $defined.Contains($name)) {
                        Add-OpenApiFinding -Context $Context -Severity Warning -Code 'OA021' -Pointer (Join-OpenApiJsonPointer -Pointer $Pointer -Segment ([string]$index), $name) -Message "Security requirement references undefined security scheme '$name'."
                    }
                }
            }
            $list.Add($map)
            $index++
        }
    }
    return , $list.ToArray()
}
