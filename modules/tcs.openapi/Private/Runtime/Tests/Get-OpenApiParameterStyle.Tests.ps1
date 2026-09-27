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

Describe 'Get-OpenApiParameterStyle' {
    It 'finds the parameter by name and location' {
        InModuleScope -ModuleName tcs.openapi {
            $parameters = @(
                @{ Name = 'id'; In = 'query'; Style = 'pipeDelimited'; Explode = $false; AllowReserved = $true }
                [pscustomobject]@{ Name = 'id'; In = 'header' }
            )
            $query = Get-OpenApiParameterStyle -Parameter $parameters -Name 'id' -In 'query'
            $query.Style | Should -Be 'pipeDelimited'
            $query.Explode | Should -BeFalse
            $query.AllowReserved | Should -BeTrue
            $header = Get-OpenApiParameterStyle -Parameter $parameters -Name 'id' -In 'header'
            $header.Style | Should -Be 'simple'
            $header.Explode | Should -BeFalse
            $header.CatchAll | Should -BeFalse
        }
    }

    It 'returns CatchAll; a missing flag (metadata of 0.1.x) is false' {
        InModuleScope -ModuleName tcs.openapi {
            $parameters = @(@{ Name = 'path'; In = 'path'; CatchAll = $true }, @{ Name = 'id'; In = 'path' })
            (Get-OpenApiParameterStyle -Parameter $parameters -Name 'path' -In 'path').CatchAll | Should -BeTrue
            (Get-OpenApiParameterStyle -Parameter $parameters -Name 'id' -In 'path').CatchAll | Should -BeFalse
        }
    }

    It 'uses the location defaults for unknown parameters' {
        InModuleScope -ModuleName tcs.openapi {
            $style = Get-OpenApiParameterStyle -Parameter $null -Name 'x' -In 'cookie'
            $style.Style | Should -Be 'form'
            $style.Explode | Should -BeTrue
            $style.AllowReserved | Should -BeFalse
        }
    }
}
