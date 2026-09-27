function Resolve-OpenApiGenNameCollision {
    <#
    .SYNOPSIS
        Makes command names unique without hashes and reports every rename as an OA040 warning.

    .DESCRIPTION
        The candidates (from Get-OpenApiGenCommandName) must already be sorted by path, then method.
        The first candidate with a name keeps it; every base name is reserved up front, so a rename
        never takes a name another operation would get on its own. A colliding candidate gets, in
        order of preference: a path segment that the first holder's path does not have ('{name}' ->
        'ByName', 'owners' -> 'Owner'), all such segments, the HTTP method ('Post'), and as a last
        resort a number (2, 3, ...). Names in -Reserved (for example the connection commands) are
        treated as taken. Comparisons ignore case. Returns { Names, Findings }, where Names are the
        candidates in the same order with Name, Noun and Renamed set.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Candidate,

        [Parameter()]
        [AllowEmptyCollection()]
        [string[]]$Reserved = @()
    )

    $comparer = [System.StringComparer]::OrdinalIgnoreCase
    $taken = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList $comparer
    $reservedSet = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList $comparer
    foreach ($name in $Reserved) {
        [void]$taken.Add($name)
        [void]$reservedSet.Add($name)
    }
    foreach ($item in $Candidate) {
        [void]$taken.Add($item.Name)
    }

    $holders = New-Object -TypeName 'System.Collections.Generic.Dictionary[string,object]' -ArgumentList $comparer
    $names = New-Object -TypeName System.Collections.ArrayList
    $findings = New-Object -TypeName System.Collections.ArrayList

    $segmentWords = {
        param([string]$Segment)
        $parameterMatch = [regex]::Match($Segment, '^\{(.+)\}$')
        if ($parameterMatch.Success) {
            'By'
            Split-OpenApiGenWord -Value $parameterMatch.Groups[1].Value
            return
        }
        Split-OpenApiGenWord -Value $Segment
    }
    $joinNoun = {
        param([string]$Noun, [string[]]$Words)
        $all = @($Words | Where-Object -FilterScript { $_ -ne '' })
        if ($all.Count -eq 0) {
            return $Noun
        }
        $all[$all.Count - 1] = ConvertTo-OpenApiGenSingular -Word $all[$all.Count - 1]
        return $Noun + (ConvertTo-OpenApiGenPascalCase -Word $all)
    }

    foreach ($item in $Candidate) {
        $isFree = (-not $holders.ContainsKey($item.Name)) -and (-not $reservedSet.Contains($item.Name))
        if ($isFree) {
            $holders[$item.Name] = $item
            [void]$names.Add(($item | Select-Object -Property * -ExcludeProperty Findings | Add-Member -NotePropertyName Renamed -NotePropertyValue $false -PassThru))
            continue
        }

        $holder = $null
        if ($holders.ContainsKey($item.Name)) {
            $holder = $holders[$item.Name]
        }
        $ownSegments = @(([string]$item.Path).Split('/') | Where-Object -FilterScript { $_ -ne '' })
        $holderSegments = @()
        if ($null -ne $holder) {
            $holderSegments = @(([string]$holder.Path).Split('/') | Where-Object -FilterScript { $_ -ne '' } | ForEach-Object -Process { $_.ToLowerInvariant() })
        }
        $distinct = @($ownSegments | Where-Object -FilterScript { $holderSegments -notcontains $_.ToLowerInvariant() })
        [array]::Reverse($distinct)

        $options = New-Object -TypeName System.Collections.ArrayList
        foreach ($segment in $distinct) {
            [void]$options.Add((& $joinNoun $item.Noun @(& $segmentWords $segment)))
        }
        if ($distinct.Count -gt 1) {
            $allWords = @()
            for ($i = $distinct.Count - 1; $i -ge 0; $i--) {
                $allWords += @(& $segmentWords $distinct[$i])
            }
            [void]$options.Add((& $joinNoun $item.Noun $allWords))
        }
        [void]$options.Add($item.Noun + (ConvertTo-OpenApiGenPascalCase -Word @($item.Method)))

        $newNoun = $null
        foreach ($option in $options) {
            if (-not $taken.Contains("$($item.Verb)-$option")) {
                $newNoun = $option
                break
            }
        }
        $number = 2
        while ($null -eq $newNoun) {
            if (-not $taken.Contains("$($item.Verb)-$($item.Noun)$number")) {
                $newNoun = "$($item.Noun)$number"
            }
            $number++
        }
        $newName = "$($item.Verb)-$newNoun"
        [void]$taken.Add($newName)
        $holders[$newName] = $item

        $other = 'a command of the generated module'
        if ($null -ne $holder) {
            $other = "operation '$($holder.OperationId)' ($($holder.Method) $($holder.Path))"
        }
        $operation = [pscustomobject]@{ OperationId = $item.OperationId; Method = $item.Method; Path = $item.Path }
        [void]$findings.Add((New-OpenApiGenFinding -Severity Warning -Code 'OA040' -Operation $operation -Message "Command name '$($item.Name)' for operation '$($item.OperationId)' collides with $other; renamed to '$newName'."))

        $renamed = $item | Select-Object -Property * -ExcludeProperty Findings
        $renamed.Noun = $newNoun
        $renamed.Name = $newName
        [void]$names.Add(($renamed | Add-Member -NotePropertyName Renamed -NotePropertyValue $true -PassThru))
    }

    return [pscustomobject]@{
        Names    = $names.ToArray()
        Findings = $findings.ToArray()
    }
}
