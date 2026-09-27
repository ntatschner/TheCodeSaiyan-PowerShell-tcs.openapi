BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenAuthExample' {
    BeforeAll {
        function Get-TestExample {
            param($Document)
            InModuleScope tcs.openapi -Parameters @{ Document = $Document } {
                param($Document)
                Get-OpenApiGenAuthExample -Document $Document
            }
        }
        $script:schemes = [ordered]@{
            key    = [pscustomobject]@{ Type = 'apiKey'; In = 'header'; ParameterName = 'X-API-Key'; Scheme = $null; Flows = $null }
            basic  = [pscustomobject]@{ Type = 'http'; In = $null; ParameterName = $null; Scheme = 'basic'; Flows = $null }
            bearer = [pscustomobject]@{ Type = 'http'; In = $null; ParameterName = $null; Scheme = 'Bearer'; Flows = $null }
            client = [pscustomobject]@{ Type = 'oauth2'; In = $null; ParameterName = $null; Scheme = $null; Flows = [ordered]@{ clientCredentials = [pscustomobject]@{ TokenUrl = 'https://t' } } }
            code   = [pscustomobject]@{ Type = 'oauth2'; In = $null; ParameterName = $null; Scheme = $null; Flows = [ordered]@{ authorizationCode = [pscustomobject]@{ TokenUrl = 'https://t' } } }
            oidc   = [pscustomobject]@{ Type = 'openIdConnect'; In = $null; ParameterName = $null; Scheme = $null; Flows = $null }
            mtls   = [pscustomobject]@{ Type = 'mutualTLS'; In = $null; ParameterName = $null; Scheme = $null; Flows = $null }
        }
    }

    It 'uses <Expected> for the <Scheme> scheme' -TestCases @(
        @{ Scheme = 'key'; Expected = " -ApiKey (Read-Host -AsSecureString -Prompt 'API key')" }
        @{ Scheme = 'basic'; Expected = ' -Credential (Get-Credential)' }
        @{ Scheme = 'bearer'; Expected = " -BearerToken (Read-Host -AsSecureString -Prompt 'Token')" }
        @{ Scheme = 'client'; Expected = " -ClientId '<client id>' -ClientSecret (Read-Host -AsSecureString -Prompt 'Client secret')" }
        @{ Scheme = 'code'; Expected = " -BearerToken (Read-Host -AsSecureString -Prompt 'Token')" }
        @{ Scheme = 'oidc'; Expected = " -BearerToken (Read-Host -AsSecureString -Prompt 'Token')" }
        @{ Scheme = 'mtls'; Expected = '' }
    ) {
        $document = New-TestDocument -SecuritySchemes $script:schemes -Security @([ordered]@{ $Scheme = @() })
        Get-TestExample -Document $document | Should -BeExactly $Expected
    }

    It 'gives every scheme of the first document requirement' {
        $document = New-TestDocument -SecuritySchemes $script:schemes -Security @([ordered]@{ key = @(); basic = @() }, [ordered]@{ bearer = @() })
        Get-TestExample -Document $document | Should -BeExactly " -ApiKey (Read-Host -AsSecureString -Prompt 'API key') -Credential (Get-Credential)"
    }

    It 'uses the first operation requirement (by path, then method) without a document default' {
        $operations = @(
            (New-TestOperation -OperationId 'b' -Method GET -Path '/b' -Security @([ordered]@{ basic = @() }))
            (New-TestOperation -OperationId 'open' -Method GET -Path '/a' -Security @())
            (New-TestOperation -OperationId 'a' -Method POST -Path '/a' -Security @([ordered]@{ key = @() }))
        )
        $document = New-TestDocument -SecuritySchemes $script:schemes -Operations $operations
        Get-TestExample -Document $document | Should -BeExactly " -ApiKey (Read-Host -AsSecureString -Prompt 'API key')"
    }

    It 'falls back to the first scheme by name, and to nothing without schemes' {
        $document = New-TestDocument -SecuritySchemes ([ordered]@{ zeta = $script:schemes['key']; alpha = $script:schemes['basic'] })
        Get-TestExample -Document $document | Should -BeExactly ' -Credential (Get-Credential)'
        Get-TestExample -Document (New-TestDocument) | Should -BeExactly ''
    }

    It 'skips schemes the requirement names but the document does not define' {
        $document = New-TestDocument -SecuritySchemes $script:schemes -Security @([ordered]@{ missing = @(); key = @() })
        Get-TestExample -Document $document | Should -BeExactly " -ApiKey (Read-Host -AsSecureString -Prompt 'API key')"
    }
}
