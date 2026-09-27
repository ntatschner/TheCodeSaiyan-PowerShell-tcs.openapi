BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Resolve-OpenApiGenOption' {
    It 'resolves defaults that do not depend on the machine' {
        $option = InModuleScope tcs.openapi { Resolve-OpenApiGenOption -ModuleName 'pet-store.api' -OutputPath '/out' -GeneratorVersion '0.1.0' }
        $option.Service | Should -Be 'pet-store.api'
        $option.Prefix | Should -Be 'PetStoreApi'
        $option.NounPrefix | Should -Be ''
        $option.ModuleVersion | Should -Be '0.1.0'
        $option.Author | Should -Be 'tcs.openapi'
        $option.ModulePath | Should -Be (Join-Path -Path '/out' -ChildPath 'pet-store.api')
        $option.UnwrapProperty | Should -Be ''
    }

    It 'keeps the unwrap property' {
        (InModuleScope tcs.openapi { Resolve-OpenApiGenOption -ModuleName 'Pets' -OutputPath '/out' -UnwrapProperty 'data' -GeneratorVersion '0.2.0' }).UnwrapProperty | Should -Be 'data'
    }

    It 'uses the given prefix, version and author' {
        $option = InModuleScope tcs.openapi { Resolve-OpenApiGenOption -ModuleName 'Pets' -OutputPath '/out' -NounPrefix 'Pet' -ModuleVersion '2.3.4' -Author 'Me' -GeneratorVersion '0.1.0' }
        $option.Prefix | Should -Be 'Pet'
        $option.ModuleVersion | Should -Be '2.3.4'
        $option.Author | Should -Be 'Me'
    }

    It 'rejects an invalid module name or prefix' {
        { InModuleScope tcs.openapi { Resolve-OpenApiGenOption -ModuleName '1bad' -OutputPath '/out' -GeneratorVersion '0.1.0' } } | Should -Throw '*not valid*'
        { InModuleScope tcs.openapi { Resolve-OpenApiGenOption -ModuleName 'Good' -OutputPath '/out' -NounPrefix 'a-b' -GeneratorVersion '0.1.0' } } | Should -Throw '*not valid*'
    }
}
