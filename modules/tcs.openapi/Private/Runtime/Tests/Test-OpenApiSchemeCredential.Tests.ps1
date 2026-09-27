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

Describe 'Test-OpenApiSchemeCredential' {
    It 'checks the credential each scheme type needs' {
        InModuleScope -ModuleName tcs.openapi {
            $secret = ConvertTo-SecureString -String 's' -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential -ArgumentList 'u', $secret
            $empty = Build-OpenApiContext -Service 'S' -BaseUri 'https://a'
            $full = Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -ApiKey $secret -Credential $credential -BearerToken $secret
            $client = Build-OpenApiContext -Service 'S' -BaseUri 'https://a' -ClientId 'id' -ClientSecret $secret
            $schemes = @(
                @{ Type = 'apiKey'; In = 'header' }
                @{ Type = 'http'; Scheme = 'basic' }
                @{ Type = 'http'; Scheme = 'bearer' }
                @{ Type = 'openIdConnect' }
            )
            foreach ($scheme in $schemes) {
                Test-OpenApiSchemeCredential -Scheme $scheme -Context $empty | Should -BeFalse
                Test-OpenApiSchemeCredential -Scheme $scheme -Context $full | Should -BeTrue
            }
            Test-OpenApiSchemeCredential -Scheme @{ Type = 'http'; Scheme = 'digest' } -Context $full | Should -BeFalse
            Test-OpenApiSchemeCredential -Scheme $null -Context $full | Should -BeFalse
            $oauth = @{ Type = 'oauth2'; Flows = @{ clientCredentials = @{ TokenUrl = 'https://t' } } }
            Test-OpenApiSchemeCredential -Scheme $oauth -Context $client | Should -BeTrue
            Test-OpenApiSchemeCredential -Scheme @{ Type = 'oauth2' } -Context $client | Should -BeFalse
            Test-OpenApiSchemeCredential -Scheme @{ Type = 'oauth2' } -Context $full | Should -BeTrue
        }
    }
}
