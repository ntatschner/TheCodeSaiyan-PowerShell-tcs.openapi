function Get-OpenApiGenCommandName {
    <#
    .SYNOPSIS
        Works out the Verb-Noun command name for one operation, before collisions are resolved.

    .DESCRIPTION
        1. x-ps-name (a full Verb-Noun with an approved verb) wins; otherwise x-ps-verb and x-ps-noun
           replace the derived verb and noun.
        2. From the operationId: the words are split, the first word is mapped to a verb (see
           Resolve-OpenApiGenVerb) and the rest is the noun. An unknown first word gives the method's
           default verb and stays in the noun. When the noun then ends with the operation's own HTTP method
           word (Get, Post, Put, Patch, Delete, Head, Options, Trace) and other words remain, that word is
           dropped: ConnectorPost (POST) -> New-Connector, ConnectorGet (GET) -> Get-Connector.
        3. Without an operationId (or when the document model generated it, finding OA010): the method's
           default verb and the last non-parameter path segment.
        4. Noun = NounPrefix + PascalCase words with the last word singularised (the last word with
           letters, so a trailing number is skipped); only A-Z, a-z, 0-9.
        Invalid overrides are ignored with an OA040 warning finding.
        Returns { OperationId, Method, Path, Verb, Noun, BaseNoun, Name, Source, IsList, Findings }.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Operation,

        [Parameter()]
        [AllowEmptyString()]
        [string]$NounPrefix = '',

        [Parameter()]
        [switch]$OperationIdGenerated
    )

    $findings = New-Object -TypeName System.Collections.ArrayList
    $approved = Get-OpenApiGenApprovedVerb
    $method = ([string]$Operation.Method).ToUpperInvariant()
    $prefix = ConvertTo-OpenApiGenPascalCase -Word @($NounPrefix)
    if ($NounPrefix -cmatch '^[A-Za-z0-9]+$') {
        $prefix = $NounPrefix
    }

    # Path words: last segment that is not a parameter
    $pathWords = @()
    $segments = @(([string]$Operation.Path).Split('/') | Where-Object -FilterScript { $_ -ne '' -and $_ -notmatch '\{' })
    if ($segments.Count -gt 0) {
        $pathWords = @(Split-OpenApiGenWord -Value $segments[$segments.Count - 1])
    }
    if ($pathWords.Count -eq 0) {
        $pathWords = @('Root')
    }

    $source = 'operationId'
    $isList = $false
    $operationId = [string]$Operation.OperationId
    if ($OperationIdGenerated -or [string]::IsNullOrEmpty($operationId)) {
        $source = 'path'
        $verb = (Resolve-OpenApiGenVerb -Method $method).Verb
        $nounWords = $pathWords
    }
    else {
        $words = @(Split-OpenApiGenWord -Value $operationId)
        $resolved = $null
        if ($words.Count -gt 0) {
            $resolved = Resolve-OpenApiGenVerb -Word $words[0] -Method $method
        }
        if ($null -ne $resolved) {
            $verb = $resolved.Verb
            $isList = $resolved.IsList
            $nounWords = @($words | Select-Object -Skip 1)
        }
        else {
            $verb = (Resolve-OpenApiGenVerb -Method $method).Verb
            $nounWords = $words
        }
        # 'ConnectorGet' (GET): the method word repeats what the verb says
        $nounWords = @($nounWords)
        if ($nounWords.Count -gt 1 -and ([string]$nounWords[$nounWords.Count - 1]).ToUpperInvariant() -eq $method) {
            $nounWords = @($nounWords | Select-Object -First ($nounWords.Count - 1))
        }
        if ($nounWords.Count -eq 0) {
            $nounWords = $pathWords
        }
    }
    # Singularise the last word that has letters ('listOrders_2' -> 'Order2')
    $nounWords = @($nounWords)
    for ($i = $nounWords.Count - 1; $i -ge 0; $i--) {
        if ($nounWords[$i] -match '\p{L}') {
            $nounWords[$i] = ConvertTo-OpenApiGenSingular -Word $nounWords[$i]
            break
        }
    }
    $baseNoun = ConvertTo-OpenApiGenPascalCase -Word $nounWords
    if ($baseNoun -eq '') {
        $baseNoun = 'Resource'
    }

    # Overrides from x-ps-verb / x-ps-noun / x-ps-name
    $extensions = $Operation.Extensions
    $overrideVerb = Get-OpenApiGenMapValue -Map $extensions -Key 'x-ps-verb'
    if ($null -ne $overrideVerb) {
        $match = @($approved | Where-Object -FilterScript { $_ -eq [string]$overrideVerb })
        if ($match.Count -gt 0) {
            $verb = $match[0]
            $source = 'x-ps-verb'
        }
        else {
            [void]$findings.Add((New-OpenApiGenFinding -Severity Warning -Code 'OA040' -Operation $Operation -PointerSuffix '/x-ps-verb' -Message "x-ps-verb '$overrideVerb' is not an approved PowerShell verb and was ignored; the command uses '$verb'."))
        }
    }
    $overrideNoun = Get-OpenApiGenMapValue -Map $extensions -Key 'x-ps-noun'
    if ($null -ne $overrideNoun) {
        $cleanNoun = [string]$overrideNoun
        if ($cleanNoun -cnotmatch '^[A-Za-z0-9]+$') {
            $cleanNoun = ConvertTo-OpenApiGenPascalCase -Value $cleanNoun
        }
        elseif ($cleanNoun.Length -gt 0) {
            $cleanNoun = $cleanNoun.Substring(0, 1).ToUpperInvariant() + $cleanNoun.Substring(1)
        }
        if ($cleanNoun -ne '') {
            $baseNoun = $cleanNoun
            $source = 'x-ps-noun'
        }
    }
    $noun = $prefix + $baseNoun

    $overrideName = Get-OpenApiGenMapValue -Map $extensions -Key 'x-ps-name'
    if ($null -ne $overrideName) {
        $nameMatch = [regex]::Match([string]$overrideName, '^([A-Za-z]+)-([A-Za-z0-9]+)$')
        $verbMatch = @()
        if ($nameMatch.Success) {
            $verbMatch = @($approved | Where-Object -FilterScript { $_ -eq $nameMatch.Groups[1].Value })
        }
        if ($verbMatch.Count -gt 0) {
            $verb = $verbMatch[0]
            $noun = $nameMatch.Groups[2].Value
            $baseNoun = $noun
            if ($prefix -ne '' -and $noun.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase) -and $noun.Length -gt $prefix.Length) {
                $baseNoun = $noun.Substring($prefix.Length)
            }
            $source = 'x-ps-name'
        }
        else {
            [void]$findings.Add((New-OpenApiGenFinding -Severity Warning -Code 'OA040' -Operation $Operation -PointerSuffix '/x-ps-name' -Message "x-ps-name '$overrideName' is not a Verb-Noun name with an approved verb and was ignored; the command uses '$verb-$noun'."))
        }
    }

    return [pscustomobject]@{
        PSTypeName  = 'Tcs.OpenApi.CommandName'
        OperationId = $Operation.OperationId
        Method      = $method
        Path        = [string]$Operation.Path
        Verb        = $verb
        Noun        = $noun
        BaseNoun    = $baseNoun
        Name        = "$verb-$noun"
        Source      = $source
        IsList      = $isList
        Findings    = $findings.ToArray()
    }
}
