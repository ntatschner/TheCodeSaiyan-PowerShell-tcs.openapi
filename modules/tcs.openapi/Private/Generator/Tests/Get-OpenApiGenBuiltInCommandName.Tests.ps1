BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiGenBuiltInCommandName' {
    BeforeAll {
        $names = InModuleScope tcs.openapi { Get-OpenApiGenBuiltInCommandName }
    }

    It 'returns a fixed, ordinally sorted list without duplicates' {
        $names.Count | Should -BeGreaterThan 250
        $sorted = [string[]]$names.Clone()
        [array]::Sort($sorted, [System.StringComparer]::Ordinal)
        $names | Should -Be $sorted
        @($names | Select-Object -Unique).Count | Should -Be $names.Count
    }

    It 'contains the common core commands, including Windows-only ones' {
        foreach ($name in @('Get-Item', 'New-Item', 'Remove-Item', 'Get-Content', 'Invoke-RestMethod', 'Get-Process', 'Get-Service', 'Get-Acl', 'Out-GridView', 'ConvertTo-Json')) {
            $names | Should -Contain $name
        }
    }

    It 'covers every command the core modules export in this session' {
        $modules = 'Microsoft.PowerShell.Management', 'Microsoft.PowerShell.Utility', 'Microsoft.PowerShell.Core', 'Microsoft.PowerShell.Security'
        $missing = @(Get-Command -Module $modules -CommandType Cmdlet, Function -ErrorAction SilentlyContinue |
                Where-Object -FilterScript { $_.Name -like '*-*' -and $names -notcontains $_.Name } | ForEach-Object -Process { $_.Name })
        # The list was taken from PowerShell 7.4 on Linux; other releases and Windows may differ slightly
        $isLinuxOrMac = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Unix
        if ($isLinuxOrMac -and $PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -eq 4) {
            $missing | Should -BeNullOrEmpty
        }
        else {
            Set-ItResult -Skipped -Because 'the list was taken from PowerShell 7.4 on Linux'
        }
    }
}
