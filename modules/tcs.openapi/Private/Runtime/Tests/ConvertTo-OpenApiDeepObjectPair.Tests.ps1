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

Describe 'ConvertTo-OpenApiDeepObjectPair' {
    It 'flattens nested objects and repeats arrays' {
        InModuleScope -ModuleName tcs.openapi {
            $value = [ordered]@{ a = 1; b = [ordered]@{ c = 'x y' }; d = @(1, 2) }
            @(ConvertTo-OpenApiDeepObjectPair -Prefix 'f' -Value $value) | Should -Be @('f[a]=1', 'f[b][c]=x%20y', 'f[d]=1', 'f[d]=2')
        }
    }

    It 'honours allowReserved for values' {
        InModuleScope -ModuleName tcs.openapi {
            @(ConvertTo-OpenApiDeepObjectPair -Prefix 'f' -Value @{ p = 'a/b' } -AllowReserved) | Should -Be @('f[p]=a/b')
        }
    }
}
