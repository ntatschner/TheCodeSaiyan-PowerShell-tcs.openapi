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

Describe 'Select-OpenApiSecurityRequirement' {
    BeforeAll {
        InModuleScope -ModuleName tcs.openapi {
            $script:testSchemes = @{
                key    = @{ Type = 'apiKey'; In = 'header'; ParameterName = 'X-Key' }
                basic  = @{ Type = 'http'; Scheme = 'basic' }
                bearer = @{ Type = 'http'; Scheme = 'Bearer' }
            }
            $script:testContext = Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -BearerToken (ConvertTo-SecureString -String 't' -AsPlainText -Force)
        }
    }

    It 'returns None for Security = [] and for an empty requirement' {
        InModuleScope -ModuleName tcs.openapi {
            (Select-OpenApiSecurityRequirement -Operation @{ Security = @(); SecuritySchemes = $script:testSchemes } -Context $script:testContext).Mode | Should -Be 'None'
            (Select-OpenApiSecurityRequirement -Operation @{ Security = @(@{ basic = @() }, @{}); SecuritySchemes = $script:testSchemes } -Context $script:testContext).Mode | Should -Be 'None'
        }
    }

    It 'selects the first requirement the context can satisfy, with its scopes' {
        InModuleScope -ModuleName tcs.openapi {
            $operation = [pscustomobject]@{ Security = @([pscustomobject]@{ basic = @() }, [pscustomobject]@{ bearer = @('read', 'write') }); SecuritySchemes = [pscustomobject]$script:testSchemes }
            $selection = Select-OpenApiSecurityRequirement -Operation $operation -Context $script:testContext
            $selection.Mode | Should -Be 'Selected'
            $selection.Schemes.Count | Should -Be 1
            $selection.Schemes[0].Name | Should -Be 'bearer'
            $selection.Schemes[0].Scopes | Should -Be @('read', 'write')
        }
    }

    It 'returns Unsatisfied when no requirement can be met' {
        InModuleScope -ModuleName tcs.openapi {
            (Select-OpenApiSecurityRequirement -Operation @{ Security = @(@{ key = @() }); SecuritySchemes = $script:testSchemes } -Context $script:testContext).Mode | Should -Be 'Unsatisfied'
        }
    }

    It 'uses DefaultSecurity, else each scheme alone, when Security is null' {
        InModuleScope -ModuleName tcs.openapi {
            $selection = Select-OpenApiSecurityRequirement -Operation @{ Security = $null; DefaultSecurity = @(@{ bearer = @() }); SecuritySchemes = $script:testSchemes } -Context $script:testContext
            $selection.Schemes[0].Name | Should -Be 'bearer'
            $selection = Select-OpenApiSecurityRequirement -Operation @{ SecuritySchemes = $script:testSchemes } -Context $script:testContext
            $selection.Mode | Should -Be 'Selected'
            $selection.Schemes[0].Name | Should -Be 'bearer'
        }
    }

    It 'returns Generic without any security metadata' {
        InModuleScope -ModuleName tcs.openapi {
            (Select-OpenApiSecurityRequirement -Operation @{ OperationId = 'x' } -Context $script:testContext).Mode | Should -Be 'Generic'
        }
    }
}
