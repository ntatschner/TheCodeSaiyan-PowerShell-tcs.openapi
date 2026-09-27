BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Get-OpenApiMember' {
    It 'reads hashtables, ordered dictionaries and objects' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiMember -InputObject @{ Name = 'a' } -Name 'name' | Should -Be 'a'
            Get-OpenApiMember -InputObject ([ordered]@{ Name = 'b' }) -Name 'Name' | Should -Be 'b'
            Get-OpenApiMember -InputObject ([pscustomobject]@{ Name = 'c' }) -Name 'Name' | Should -Be 'c'
            Get-OpenApiMember -InputObject @{} -Name 'Missing' | Should -BeNullOrEmpty
            Get-OpenApiMember -InputObject $null -Name 'Name' | Should -BeNullOrEmpty
        }
    }

    It 'returns collections as one object' {
        InModuleScope -ModuleName tcs.openapi {
            $value = Get-OpenApiMember -InputObject @{ List = @('only') } -Name 'List'
            , $value | Should -BeOfType ([object[]])
            $value.Count | Should -Be 1
            $empty = Get-OpenApiMember -InputObject ([pscustomobject]@{ List = @() }) -Name 'List'
            , $empty | Should -BeOfType ([object[]])
        }
    }
}
