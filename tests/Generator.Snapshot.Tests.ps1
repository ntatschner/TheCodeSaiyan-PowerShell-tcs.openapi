BeforeDiscovery {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/New-TestOpenApiModel.ps1')
    $cases = @(Get-TestSnapshotCase | ForEach-Object -Process { @{ Name = $_.Name; ModuleName = $_.ModuleName; NounPrefix = $_.NounPrefix } })
}

BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/New-TestOpenApiModel.ps1')
    $SnapshotRoot = Join-Path -Path $PSScriptRoot -ChildPath 'Snapshots'
    $OutputRoot = Join-Path -Path $TestDrive -ChildPath 'snapshots'

    function Get-RelativeFile {
        param([string]$Path)
        $root = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
        Get-ChildItem -LiteralPath $root -Recurse -File | ForEach-Object -Process { $_.FullName.Substring($root.Length + 1).Replace('\', '/') } | Sort-Object
    }
}

Describe 'Generated module snapshot <Name>' -ForEach $cases {
    BeforeAll {
        $parameters = @{
            Document   = (New-TestOpenApiModel -Name $Name)
            ModuleName = $ModuleName
            OutputPath = (Join-Path -Path $OutputRoot -ChildPath $Name)
        }
        if ($NounPrefix) {
            $parameters['NounPrefix'] = $NounPrefix
        }
        $result = New-OpenApiModule @parameters
        $expectedRoot = Join-Path -Path (Join-Path -Path $SnapshotRoot -ChildPath $Name) -ChildPath $ModuleName
    }

    It 'has a checked-in snapshot (run tests/Helpers/Update-Snapshots.ps1 to create it)' {
        Test-Path -LiteralPath $expectedRoot | Should -BeTrue
    }

    It 'writes the same files as the snapshot' {
        @(Get-RelativeFile -Path $result.Path) | Should -Be @(Get-RelativeFile -Path $expectedRoot)
    }

    It 'writes byte-identical content (run tests/Helpers/Update-Snapshots.ps1 after a deliberate change)' {
        foreach ($relative in Get-RelativeFile -Path $expectedRoot) {
            $actual = [System.IO.File]::ReadAllBytes((Join-Path -Path $result.Path -ChildPath $relative))
            $expected = [System.IO.File]::ReadAllBytes((Join-Path -Path $expectedRoot -ChildPath $relative))
            [System.Convert]::ToBase64String($actual) | Should -BeExactly ([System.Convert]::ToBase64String($expected)) -Because $relative
        }
    }

    It 'passes PSScriptAnalyzer with the repository settings' {
        $settings = Join-Path -Path $RepoRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
        $findings = @(Invoke-ScriptAnalyzer -Path $result.Path -Recurse -Settings $settings -Severity Warning, Error)
        ($findings | ForEach-Object -Process { "$($_.ScriptName):$($_.Line) $($_.RuleName) $($_.Message)" }) -join "`n" | Should -BeNullOrEmpty
    }

    It 'writes only UTF-8, with a BOM exactly when the file is not ASCII, and LF line endings' {
        foreach ($relative in Get-RelativeFile -Path $result.Path) {
            $bytes = [System.IO.File]::ReadAllBytes((Join-Path -Path $result.Path -ChildPath $relative))
            $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
            $nonAscii = @($bytes | Where-Object -FilterScript { $_ -gt 0x7F }).Count -gt 0
            $hasBom | Should -Be $nonAscii -Because $relative
            $bytes | Should -Not -Contain 13 -Because $relative
        }
    }

    It 'parses every PowerShell file' {
        foreach ($relative in @(Get-RelativeFile -Path $result.Path | Where-Object -FilterScript { $_ -match '\.ps(m|d)?1$' })) {
            $tokens = $null
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path -Path $result.Path -ChildPath $relative), [ref]$tokens, [ref]$errors)
            @($errors).Count | Should -Be 0 -Because $relative
        }
    }
}
