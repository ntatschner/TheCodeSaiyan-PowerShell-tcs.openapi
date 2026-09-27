BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Write-OpenApiGenPlan' {
    BeforeAll {
        function New-TestFilePlan {
            param([string]$Root, [hashtable]$Content)
            $files = foreach ($key in ($Content.Keys | Sort-Object)) {
                $kind = 'Function'
                if ($key -eq 'Overrides.ps1') { $kind = 'Overrides' }
                [pscustomobject]@{ RelativePath = $key; Kind = $kind; Content = $Content[$key]; FunctionName = $null; OperationId = $null }
            }
            [pscustomobject]@{ ModulePath = $Root; Files = @($files) }
        }
        function Write-TestPlan {
            param($Plan, [switch]$Force, [switch]$WhatIf)
            InModuleScope tcs.openapi -Parameters @{ Plan = $Plan; Force = [bool]$Force; WhatIf = [bool]$WhatIf } {
                param($Plan, $Force, $WhatIf)
                Write-OpenApiGenPlan -Plan $Plan -Force:$Force -WhatIf:$WhatIf
            }
        }
    }

    BeforeEach {
        $root = Join-Path -Path $TestDrive -ChildPath ([guid]::NewGuid().ToString('n'))
    }

    It 'creates files and folders' {
        $result = @(Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'A'; 'Public/X/b.ps1' = 'B' }))
        $result.Action | Should -Be @('Created', 'Created')
        [System.IO.File]::ReadAllText((Join-Path -Path $root -ChildPath 'a.txt')) | Should -BeExactly 'A'
        Test-Path -LiteralPath (Join-Path -Path (Join-Path -Path (Join-Path -Path $root -ChildPath 'Public') -ChildPath 'X') -ChildPath 'b.ps1') | Should -BeTrue
    }

    It 'writes UTF-8 without BOM for ASCII and with BOM otherwise' {
        $text = 'caf' + [char]0xE9
        Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'plain'; 'b.txt' = $text }) | Out-Null
        [System.IO.File]::ReadAllBytes((Join-Path -Path $root -ChildPath 'a.txt')) | Should -Be ([byte[]][char[]]'plain')
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path -Path $root -ChildPath 'b.txt'))
        $bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
        [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3) | Should -BeExactly $text
    }

    It 'writes nothing with -WhatIf and reports the planned action' {
        $result = @(Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'A' }) -WhatIf)
        $result[0].Action | Should -Be 'Skipped'
        $result[0].PlannedAction | Should -Be 'Create'
        Test-Path -LiteralPath $root | Should -BeFalse
    }

    It 'reports identical files as Unchanged without -Force' {
        Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'A' }) | Out-Null
        (Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'A' })).Action | Should -Be 'Unchanged'
    }

    It 'refuses to replace a changed file without -Force and writes nothing' {
        Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'A' }) | Out-Null
        { Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'B'; 'new.txt' = 'N' }) } | Should -Throw '*-Force*'
        [System.IO.File]::ReadAllText((Join-Path -Path $root -ChildPath 'a.txt')) | Should -BeExactly 'A'
        Test-Path -LiteralPath (Join-Path -Path $root -ChildPath 'new.txt') | Should -BeFalse
    }

    It 'replaces a changed file with -Force' {
        Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'A' }) | Out-Null
        (Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'a.txt' = 'B' }) -Force).Action | Should -Be 'Replaced'
        [System.IO.File]::ReadAllText((Join-Path -Path $root -ChildPath 'a.txt')) | Should -BeExactly 'B'
    }

    It 'never overwrites Overrides.ps1, even with -Force' {
        Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'Overrides.ps1' = 'generated' }) | Out-Null
        $path = Join-Path -Path $root -ChildPath 'Overrides.ps1'
        [System.IO.File]::WriteAllText($path, 'mine')
        (Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'Overrides.ps1' = 'generated again' })).Action | Should -Be 'Preserved'
        (Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'Overrides.ps1' = 'generated again' }) -Force).Action | Should -Be 'Preserved'
        [System.IO.File]::ReadAllText($path) | Should -BeExactly 'mine'
    }

    It 'removes generated command files that are no longer planned, only with -Force' {
        Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'Public/X/Old-Thing.ps1' = 'old'; 'Public/X/Keep-Thing.ps1' = 'keep' }) | Out-Null
        { Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'Public/X/Keep-Thing.ps1' = 'keep' }) } | Should -Throw '*-Force*'
        $result = @(Write-TestPlan -Plan (New-TestFilePlan -Root $root -Content @{ 'Public/X/Keep-Thing.ps1' = 'keep' }) -Force)
        ($result | Where-Object -FilterScript { $_.RelativePath -eq 'Public/X/Old-Thing.ps1' }).Action | Should -Be 'Removed'
        Test-Path -LiteralPath (Join-Path -Path (Join-Path -Path (Join-Path -Path $root -ChildPath 'Public') -ChildPath 'X') -ChildPath 'Old-Thing.ps1') | Should -BeFalse
    }
}
