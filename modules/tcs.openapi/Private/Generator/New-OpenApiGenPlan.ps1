function New-OpenApiGenPlan {
    <#
    .SYNOPSIS
        Builds the generation plan for a module: every file with its content, the functions, the
        generator findings and the skipped operations. Writes nothing.

    .DESCRIPTION
        Operations are processed sorted by path, then method (ordinal). For each one: the command
        name (Get-OpenApiGenCommandName, then Resolve-OpenApiGenNameCollision across all operations),
        the parameter model, the operation metadata and the rendered wrapper, which must parse and bind
        (Test-OpenApiGenFunction) or the operation is skipped. Operations the document model flags as
        Unsupported, without an operationId or with the operationId of an earlier operation (ordinal) are
        skipped too. Every skip is an OA070 finding.

        Files (RelativePath uses '/'): <Name>.psd1, <Name>.psm1, README.md, Overrides.ps1 (Kind
        'Overrides': never overwritten), OpenApi/operations.json, OpenApi/source.json (compressed, without null or empty
        properties),
        Public/<Tag>/<Verb>-<Noun>.ps1 and Public/_Connection/<Verb>-<Prefix>Context.ps1. The output
        depends only on the inputs: same document and options give the same text.

        Returns { ModuleName, ModulePath, ManifestPath, Files, Functions, Findings, Skipped }.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Builds an in-memory plan only; Write-OpenApiGenPlan does the writing.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Document,

        [Parameter(Mandatory = $true)]
        [object]$Option,

        [Parameter(Mandatory = $true)]
        [hashtable]$Template
    )

    $findings = New-Object -TypeName System.Collections.ArrayList
    $skipped = New-Object -TypeName System.Collections.ArrayList
    $files = New-Object -TypeName System.Collections.ArrayList
    $functions = New-Object -TypeName System.Collections.ArrayList
    $metadataList = New-Object -TypeName System.Collections.ArrayList

    $addSkip = {
        param($Item, [string]$Reason, [string]$Severity)
        [void]$skipped.Add([pscustomobject]@{
                OperationId = $Item.OperationId
                Method      = ([string]$Item.Method).ToUpperInvariant()
                Path        = [string]$Item.Path
                Reason      = $Reason
            })
        [void]$findings.Add((New-OpenApiGenFinding -Severity $Severity -Code 'OA070' -Operation $Item -Message "Operation '$($Item.OperationId)' ($(([string]$Item.Method).ToUpperInvariant()) $($Item.Path)) was skipped: $Reason Call it with Invoke-OpenApiRequest instead."))
    }

    # Operations whose operationId the document model generated (finding OA010)
    $generatedIds = @($Document.Findings | Where-Object -FilterScript { $null -ne $_ -and $_.Code -eq 'OA010' } | ForEach-Object -Process { [string]$_.Operation })

    $operations = Get-OpenApiGenOrdinalSorted -InputObject @($Document.Operations) -Key { [string]$_.Path + [char]0 + ([string]$_.Method).ToUpperInvariant() }
    $supported = New-Object -TypeName System.Collections.ArrayList
    $seenIds = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::Ordinal)
    foreach ($operation in $operations) {
        if ($operation.Unsupported -eq $true) {
            & $addSkip $operation 'the document model marked it as unsupported (see the earlier findings for this operation).' 'Warning'
            continue
        }
        # The metadata is keyed by operationId, so it must be present and unique
        if ([string]::IsNullOrEmpty([string]$operation.OperationId)) {
            & $addSkip $operation 'it has no operationId.' 'Error'
            continue
        }
        if (-not $seenIds.Add([string]$operation.OperationId)) {
            & $addSkip $operation 'another operation has the same operationId.' 'Error'
            continue
        }
        [void]$supported.Add($operation)
    }

    # Names
    $reservedNames = @('Set', 'Get', 'Remove') | ForEach-Object -Process { "$_-$($Option.Prefix)Context" }
    # The engine's commands must not be shadowed by a generated command
    $reservedNames += @('Get-OpenApiContext', 'Import-OpenApiDocument', 'Invoke-OpenApiRequest', 'New-OpenApiModule', 'Remove-OpenApiContext', 'Set-OpenApiContext', 'Test-OpenApiDocument')
    $candidates = @(foreach ($operation in $supported) {
            $candidate = Get-OpenApiGenCommandName -Operation $operation -NounPrefix $Option.NounPrefix -OperationIdGenerated:($generatedIds -ccontains [string]$operation.OperationId)
            foreach ($finding in $candidate.Findings) {
                [void]$findings.Add($finding)
            }
            $candidate
        })
    $resolved = Resolve-OpenApiGenNameCollision -Candidate $candidates -Reserved $reservedNames -BuiltIn (Get-OpenApiGenBuiltInCommandName) -BuiltInPrefix $Option.Prefix
    foreach ($finding in $resolved.Findings) {
        [void]$findings.Add($finding)
    }

    # Wrappers
    for ($i = 0; $i -lt $supported.Count; $i++) {
        $operation = $supported[$i]
        $name = $resolved.Names[$i]
        $model = Get-OpenApiGenParameterModel -Operation $operation -BaseNoun $name.BaseNoun -Schemas $Document.Schemas
        $metadata = ConvertTo-OpenApiGenMetadataEntry -Operation $operation -Document $Document -Service $Option.Service
        $text = ConvertTo-OpenApiGenFunction -CommandName $name -Operation $operation -ParameterModel $model -ResponseTypeName $metadata.ResponseTypeName -Template $Template['Function.ps1']
        $check = Test-OpenApiGenFunction -Text $text -FunctionName $name.Name
        if (-not $check.IsValid) {
            & $addSkip $operation ("the generated function did not pass the parse and bind check: " + ($check.Errors -join ' ') + '.') 'Error'
            continue
        }
        foreach ($finding in $model.Findings) {
            [void]$findings.Add($finding)
        }
        $tag = ''
        $tags = @($operation.Tags | Where-Object -FilterScript { -not [string]::IsNullOrWhiteSpace([string]$_) })
        if ($tags.Count -gt 0) {
            $tag = ConvertTo-OpenApiGenPascalCase -Value ([string]$tags[0])
        }
        if ($tag -eq '') {
            $tag = 'Default'
        }
        $relativePath = "Public/$tag/$($name.Name).ps1"
        [void]$files.Add([pscustomobject]@{ RelativePath = $relativePath; Kind = 'Function'; Content = $text; FunctionName = $name.Name; OperationId = $operation.OperationId })
        [void]$metadataList.Add($metadata)
        $summary = [string]$operation.Summary
        if ([string]::IsNullOrWhiteSpace($summary)) {
            $summary = [string]$operation.Description
        }
        [void]$functions.Add([pscustomobject]@{
                Name        = $name.Name
                OperationId = $operation.OperationId
                File        = $relativePath
                Tag         = $tag
                Method      = ([string]$operation.Method).ToUpperInvariant()
                Path        = [string]$operation.Path
                Summary     = $summary
            })
    }

    # Connection commands
    $connections = @(ConvertTo-OpenApiGenConnection -Prefix $Option.Prefix -Service $Option.Service -ModuleName $Option.ModuleName -Server @($Document.Servers) -Template $Template)
    foreach ($connection in $connections) {
        $check = Test-OpenApiGenFunction -Text $connection.Text -FunctionName $connection.Name
        if (-not $check.IsValid) {
            throw "The generated connection command '$($connection.Name)' is not valid: $($check.Errors -join ' ')"
        }
        [void]$files.Add([pscustomobject]@{ RelativePath = $connection.RelativePath; Kind = 'Function'; Content = $connection.Text; FunctionName = $connection.Name; OperationId = $null })
        [void]$functions.Add([pscustomobject]@{
                Name        = $connection.Name
                OperationId = $null
                File        = $connection.RelativePath
                Tag         = '_Connection'
                Method      = $null
                Path        = $null
                Summary     = "$(($connection.Name -split '-')[0]) the connection used by the commands of this module."
            })
    }

    # Module files
    $functionNames = [string[]]@($functions | ForEach-Object -Process { $_.Name })
    $manifestName = "$($Option.ModuleName).psd1"
    [void]$files.Add([pscustomobject]@{ RelativePath = $manifestName; Kind = 'Manifest'; Content = (ConvertTo-OpenApiGenManifest -Option $Option -Document $Document -FunctionName $functionNames -Template $Template['Module.psd1']); FunctionName = $null; OperationId = $null })
    $moduleValues = @{
        ModuleName       = $Option.ModuleName
        Prefix           = $Option.Prefix
        GeneratorVersion = $Option.GeneratorVersion
        ServiceLiteral   = (ConvertTo-OpenApiGenLiteral -Value $Option.Service)
    }
    [void]$files.Add([pscustomobject]@{ RelativePath = "$($Option.ModuleName).psm1"; Kind = 'RootModule'; Content = (Expand-OpenApiGenTemplate -Template $Template['Module.psm1'] -Value $moduleValues); FunctionName = $null; OperationId = $null })
    [void]$files.Add([pscustomobject]@{ RelativePath = 'Overrides.ps1'; Kind = 'Overrides'; Content = (Expand-OpenApiGenTemplate -Template $Template['Overrides.ps1'] -Value $moduleValues); FunctionName = $null; OperationId = $null })
    $readme = ConvertTo-OpenApiGenReadme -Option $Option -Document $Document -Function $functions.ToArray() -ConnectExample $connections[0].ConnectExample -Template $Template['README.md']
    [void]$files.Add([pscustomobject]@{ RelativePath = 'README.md'; Kind = 'Readme'; Content = $readme; FunctionName = $null; OperationId = $null })
    $sortedMetadata = Get-OpenApiGenOrdinalSorted -InputObject $metadataList.ToArray() -Key { [string]$_.OperationId }
    [void]$files.Add([pscustomobject]@{ RelativePath = 'OpenApi/operations.json'; Kind = 'Metadata'; Content = ((ConvertTo-OpenApiGenJson -InputObject $sortedMetadata) + "`n"); FunctionName = $null; OperationId = $null })
    [void]$files.Add([pscustomobject]@{ RelativePath = 'OpenApi/source.json'; Kind = 'Source'; Content = ((ConvertTo-OpenApiGenJson -InputObject $Document -Compress -SkipEmpty) + "`n"); FunctionName = $null; OperationId = $null })

    return [pscustomobject]@{
        PSTypeName   = 'Tcs.OpenApi.GenerationPlan'
        ModuleName   = $Option.ModuleName
        ModulePath   = $Option.ModulePath
        ManifestPath = (Join-Path -Path $Option.ModulePath -ChildPath $manifestName)
        Files        = (Get-OpenApiGenOrdinalSorted -InputObject $files.ToArray() -Key { $_.RelativePath })
        Functions    = (Get-OpenApiGenOrdinalSorted -InputObject $functions.ToArray() -Key { $_.Name })
        Findings     = $findings.ToArray()
        Skipped      = $skipped.ToArray()
    }
}
