function ConvertTo-OpenApiGenSingular {
    <#
    .SYNOPSIS
        Returns the singular form of an English word with simple rules and a list of irregular and
        uncountable words ('Pets' -> 'Pet', 'Policies' -> 'Policy', 'People' -> 'Person').

    .DESCRIPTION
        The result keeps the capitalisation of the first letter of the input. Words of two letters
        or fewer, uncountable words and words ending in 'ss', 'us' or 'is' are returned unchanged.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Word
    )

    if ($Word.Length -le 2) {
        return $Word
    }
    $irregular = @{
        'addresses' = 'address'
        'aliases'   = 'alias'
        'analyses'  = 'analysis'
        'axes'      = 'axis'
        'buses'     = 'bus'
        'caches'    = 'cache'
        'children'  = 'child'
        'cookies'   = 'cookie'
        'criteria'  = 'criterion'
        'echoes'    = 'echo'
        'feet'      = 'foot'
        'geese'     = 'goose'
        'halves'    = 'half'
        'heroes'    = 'hero'
        'indices'   = 'index'
        'knives'    = 'knife'
        'leaves'    = 'leaf'
        'lives'     = 'life'
        'matrices'  = 'matrix'
        'men'       = 'man'
        'mice'      = 'mouse'
        'movies'    = 'movie'
        'people'    = 'person'
        'potatoes'  = 'potato'
        'quizzes'   = 'quiz'
        'selves'    = 'self'
        'shelves'   = 'shelf'
        'statuses'  = 'status'
        'teeth'     = 'tooth'
        'vertices'  = 'vertex'
        'viruses'   = 'virus'
        'wives'     = 'wife'
        'wolves'    = 'wolf'
        'women'     = 'woman'
    }
    $uncountable = @(
        'alias', 'atlas', 'bias', 'canvas', 'data', 'equipment', 'feedback', 'firmware', 'gas', 'hardware',
        'information', 'media', 'metadata', 'news', 'series', 'sheep', 'software', 'species', 'status'
    )
    $lower = $Word.ToLowerInvariant()
    $singular = $null
    if ($uncountable -contains $lower) {
        return $Word
    }
    elseif ($irregular.ContainsKey($lower)) {
        $singular = $irregular[$lower]
    }
    elseif ($lower -match '(ss|us|is)$') {
        return $Word
    }
    elseif ($lower.Length -gt 4 -and $lower.EndsWith('ies')) {
        $singular = $lower.Substring(0, $lower.Length - 3) + 'y'
    }
    elseif ($lower -match '(sses|shes|ches|xes|zzes)$') {
        $singular = $lower.Substring(0, $lower.Length - 2)
    }
    elseif ($lower.EndsWith('s')) {
        $singular = $lower.Substring(0, $lower.Length - 1)
    }
    else {
        return $Word
    }
    # Keep the capitalisation of the first letter
    if ([char]::IsUpper($Word[0])) {
        return $singular.Substring(0, 1).ToUpperInvariant() + $singular.Substring(1)
    }
    return $singular
}
