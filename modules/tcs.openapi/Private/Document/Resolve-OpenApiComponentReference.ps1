function Resolve-OpenApiComponentReference {
    <#
    .SYNOPSIS
        Follows $ref chains for parameters, request bodies, responses, headers, security schemes and path items.
    .DESCRIPTION
        Returns { Node, Pointer } for the target (the node itself when it has no $ref), or $null when the
        reference is external (OA020 Error, counted so the operation is flagged Unsupported), cannot be
        resolved or is circular (OA021 Error).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Node,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    $current = $Node
    $currentPointer = $Pointer
    $seen = New-Object -TypeName System.Collections.Generic.HashSet[string] -ArgumentList ([System.StringComparer]::Ordinal)
    while ($current -is [System.Collections.IDictionary] -and $current.Contains('$ref')) {
        $reference = [string]$current['$ref']
        if (-not $reference.StartsWith('#')) {
            $Context.ExternalRefHits++
            Add-OpenApiFinding -Context $Context -Severity Error -Code 'OA020' -Pointer $currentPointer -Message "External `$ref '$reference' is not supported; the operations that use it are flagged Unsupported."
            return $null
        }
        $target = Resolve-OpenApiPointer -Root $Context.Root -Reference $reference
        if (-not $target.Found) {
            Add-OpenApiFinding -Context $Context -Severity Error -Code 'OA021' -Pointer $currentPointer -Message "`$ref '$reference' could not be resolved."
            return $null
        }
        if (-not $seen.Add($target.Pointer)) {
            Add-OpenApiFinding -Context $Context -Severity Error -Code 'OA021' -Pointer $currentPointer -Message "`$ref '$reference' is circular and could not be resolved."
            return $null
        }
        $current = $target.Value
        $currentPointer = $target.Pointer
    }
    return [pscustomobject]@{ Node = $current; Pointer = $currentPointer }
}
