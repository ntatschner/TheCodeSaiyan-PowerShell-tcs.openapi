function Write-OpenApiGenPlan {
    <#
    .SYNOPSIS
        Writes a generation plan to disk and reports what it did with every file.

    .DESCRIPTION
        The only generator function that touches the disk. For each planned file: missing -> Created;
        same bytes -> Unchanged; different -> Replaced, but only with -Force. Overrides.ps1 is created
        when missing and otherwise always Preserved, even with -Force. With -Force, generated command
        files under Public/ that the plan no longer has are Removed. Without -Force, any file that would
        be replaced or removed stops the run before anything is written.

        Every write and removal goes through ShouldProcess: with -WhatIf nothing is written and the
        affected files are reported as Skipped (PlannedAction says what would have happened).
        Files are UTF-8 with LF line endings, with a BOM only when the text is not plain ASCII.
        Returns one { RelativePath, Path, Kind, FunctionName, OperationId, Action, PlannedAction } per file.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Plan,

        [Parameter()]
        [switch]$Force
    )

    $root = $Plan.ModulePath
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
    $toFullPath = {
        param([string]$RelativePath)
        $full = $root
        foreach ($part in $RelativePath.Split('/')) {
            $full = Join-Path -Path $full -ChildPath $part
        }
        return $full
    }
    $toBytes = {
        param([string]$Text)
        $body = $utf8.GetBytes($Text)
        if ($Text -match '[^\x00-\x7F]') {
            $withBom = New-Object -TypeName 'byte[]' -ArgumentList ($body.Length + 3)
            $withBom[0] = 0xEF
            $withBom[1] = 0xBB
            $withBom[2] = 0xBF
            [System.Array]::Copy($body, 0, $withBom, 3, $body.Length)
            return , $withBom
        }
        return , $body
    }
    $sameBytes = {
        param([byte[]]$Left, [byte[]]$Right)
        return ($Left.Length -eq $Right.Length) -and ([System.Convert]::ToBase64String($Left) -ceq [System.Convert]::ToBase64String($Right))
    }

    # 1. Decide what happens to every file
    $entries = New-Object -TypeName System.Collections.ArrayList
    foreach ($file in @($Plan.Files)) {
        $fullPath = & $toFullPath $file.RelativePath
        $bytes = & $toBytes $file.Content
        $planned = 'Create'
        if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
            if ($file.Kind -eq 'Overrides') {
                $planned = 'Preserve'
            }
            elseif (& $sameBytes ([System.IO.File]::ReadAllBytes($fullPath)) $bytes) {
                $planned = 'Unchanged'
            }
            else {
                $planned = 'Replace'
            }
        }
        [void]$entries.Add([pscustomobject]@{ File = $file; Path = $fullPath; Bytes = $bytes; Planned = $planned })
    }
    $publicRoot = Join-Path -Path $root -ChildPath 'Public'
    if (Test-Path -LiteralPath $publicRoot -PathType Container) {
        $plannedPaths = New-Object -TypeName 'System.Collections.Generic.HashSet[string]' -ArgumentList ([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $entries) {
            [void]$plannedPaths.Add([System.IO.Path]::GetFullPath($entry.Path))
        }
        $existing = @(Get-ChildItem -LiteralPath $publicRoot -Filter '*.ps1' -Recurse -File | Sort-Object -Property FullName)
        foreach ($item in $existing) {
            if (-not $plannedPaths.Contains([System.IO.Path]::GetFullPath($item.FullName))) {
                $relative = 'Public/' + $item.FullName.Substring($publicRoot.Length).TrimStart('\', '/').Replace('\', '/')
                $stale = [pscustomobject]@{ RelativePath = $relative; Kind = 'Stale'; Content = $null; FunctionName = $item.BaseName; OperationId = $null }
                [void]$entries.Add([pscustomobject]@{ File = $stale; Path = $item.FullName; Bytes = $null; Planned = 'Remove' })
            }
        }
    }
    $conflicts = @($entries | Where-Object -FilterScript { $_.Planned -eq 'Replace' -or $_.Planned -eq 'Remove' })
    if ($conflicts.Count -gt 0 -and -not $Force) {
        $names = @($conflicts | Select-Object -First 5 | ForEach-Object -Process { $_.File.RelativePath }) -join ', '
        throw "The module folder '$root' already has $($conflicts.Count) generated file(s) that differ from the new output ($names). Use -Force to replace them; Overrides.ps1 is never replaced."
    }

    # 2. Apply
    foreach ($entry in $entries) {
        $action = $null
        switch ($entry.Planned) {
            'Unchanged' { $action = 'Unchanged' }
            'Preserve' { $action = 'Preserved' }
            'Remove' {
                $action = 'Skipped'
                if ($PSCmdlet.ShouldProcess($entry.Path, 'Remove generated file that is no longer in the document')) {
                    Remove-Item -LiteralPath $entry.Path -Force
                    $action = 'Removed'
                }
            }
            default {
                $action = 'Skipped'
                $verb = 'Create file'
                if ($entry.Planned -eq 'Replace') {
                    $verb = 'Replace file'
                }
                if ($PSCmdlet.ShouldProcess($entry.Path, $verb)) {
                    $directory = Split-Path -Path $entry.Path -Parent
                    if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
                        [void](New-Item -Path $directory -ItemType Directory -Force)
                    }
                    [System.IO.File]::WriteAllBytes($entry.Path, $entry.Bytes)
                    $action = 'Created'
                    if ($entry.Planned -eq 'Replace') {
                        $action = 'Replaced'
                    }
                }
            }
        }
        [pscustomobject]@{
            PSTypeName    = 'Tcs.OpenApi.GeneratedFile'
            RelativePath  = $entry.File.RelativePath
            Path          = $entry.Path
            Kind          = $entry.File.Kind
            FunctionName  = $entry.File.FunctionName
            OperationId   = $entry.File.OperationId
            Action        = $action
            PlannedAction = $entry.Planned
        }
    }
}
