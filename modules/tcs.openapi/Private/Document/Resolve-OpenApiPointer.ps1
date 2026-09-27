function Resolve-OpenApiPointer {
    <#
    .SYNOPSIS
        Resolves a local reference ('#/components/schemas/Pet') against a raw document tree.
    .DESCRIPTION
        The fragment is percent-decoded, split on '/', and each segment is unescaped ('~1' -> '/',
        then '~0' -> '~'). '#/definitions/...' is read from '#/components/schemas/...' when the tree
        has no 'definitions' (Swagger 2.0 documents are converted before they are resolved).
        Returns { Found, Value, Pointer } where Pointer is the canonical JSON pointer of the target.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Root,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Reference
    )

    $notFound = [pscustomobject]@{ Found = $false; Value = $null; Pointer = $null }
    if (-not $Reference.StartsWith('#')) {
        return $notFound
    }
    $fragment = $Reference.Substring(1)
    if ($fragment.Length -gt 0 -and -not $fragment.StartsWith('/')) {
        return $notFound
    }

    $segments = [System.Collections.Generic.List[string]]::new()
    if ($fragment.Length -gt 0) {
        foreach ($raw in $fragment.Substring(1).Split('/')) {
            $decoded = [System.Uri]::UnescapeDataString($raw)
            $segments.Add($decoded.Replace('~1', '/').Replace('~0', '~'))
        }
    }
    if ($segments.Count -ge 1 -and $segments[0] -ceq 'definitions' -and $Root -is [System.Collections.IDictionary] -and -not $Root.Contains('definitions')) {
        $segments[0] = 'schemas'
        $segments.Insert(0, 'components')
    }

    $current = $Root
    foreach ($segment in $segments) {
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($segment)) {
                return $notFound
            }
            $current = $current[$segment]
        }
        elseif ($current -is [System.Collections.IList]) {
            $index = 0
            if (-not [int]::TryParse($segment, [ref]$index) -or $index -lt 0 -or $index -ge $current.Count) {
                return $notFound
            }
            $current = $current[$index]
        }
        else {
            return $notFound
        }
    }

    $pointer = ''
    if ($segments.Count -gt 0) {
        $pointer = Join-OpenApiJsonPointer -Pointer '' -Segment $segments.ToArray()
    }
    return [pscustomobject]@{ Found = $true; Value = $current; Pointer = $pointer }
}
