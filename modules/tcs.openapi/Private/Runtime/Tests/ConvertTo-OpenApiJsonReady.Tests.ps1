BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-OpenApiJsonReady' {
    It 'converts dates to ISO 8601 strings and switches to booleans, recursively' {
        InModuleScope -ModuleName tcs.openapi {
            $date = New-Object System.DateTime -ArgumentList 2024, 1, 2, 0, 0, 0, ([System.DateTimeKind]::Utc)
            $result = ConvertTo-OpenApiJsonReady -InputObject @{ d = $date; list = @(@{ s = [switch]$true }) }
            $result['d'] | Should -BeExactly '2024-01-02T00:00:00.0000000Z'
            $result['list'][0]['s'] | Should -BeOfType ([bool])
        }
    }

    It 'keeps nulls, empty arrays and single-item arrays' {
        InModuleScope -ModuleName tcs.openapi {
            $result = ConvertTo-OpenApiJsonReady -InputObject ([pscustomobject]@{ n = $null; e = @(); one = @(1) })
            $result.Contains('n') | Should -BeTrue
            $null -eq $result['n'] | Should -BeTrue
            , $result['e'] | Should -BeOfType ([object[]])
            $result['one'].Count | Should -Be 1
        }
    }

    It 'refuses bodies nested more than 64 levels' {
        InModuleScope -ModuleName tcs.openapi {
            $deep = @{}
            $current = $deep
            foreach ($i in 1..70) {
                $current['x'] = @{}
                $current = $current['x']
            }
            { ConvertTo-OpenApiJsonReady -InputObject $deep } | Should -Throw '*64 levels*'
        }
    }
}
