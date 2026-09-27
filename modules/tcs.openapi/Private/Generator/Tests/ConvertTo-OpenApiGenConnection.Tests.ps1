BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenConnection' {
    BeforeAll {
        function ConvertTo-TestConnection {
            param([object[]]$Server)
            InModuleScope tcs.openapi -Parameters @{ Server = $Server } {
                param($Server)
                $templates = Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates')
                ConvertTo-OpenApiGenConnection -Prefix 'Shop' -Service 'Shop.Api' -ModuleName 'Shop.Api' -Server $Server -Template $templates
            }
        }
    }

    It 'renders Set, Get and Remove commands in Public/_Connection' {
        $commands = @(ConvertTo-TestConnection -Server @())
        $commands.Name | Should -Be @('Set-ShopContext', 'Get-ShopContext', 'Remove-ShopContext')
        $commands.RelativePath | Should -Be @('Public/_Connection/Set-ShopContext.ps1', 'Public/_Connection/Get-ShopContext.ps1', 'Public/_Connection/Remove-ShopContext.ps1')
        foreach ($command in $commands) {
            (InModuleScope tcs.openapi -Parameters @{ C = $command } { param($C) Test-OpenApiGenFunction -Text $C.Text -FunctionName $C.Name }).IsValid | Should -BeTrue
        }
    }

    It 'exposes the parameters of Set-OpenApiContext except -Service' {
        $set = @(ConvertTo-TestConnection -Server @())[0]
        $check = InModuleScope tcs.openapi -Parameters @{ C = $set } { param($C) Test-OpenApiGenFunction -Text $C.Text -FunctionName $C.Name }
        foreach ($name in @('BaseUri', 'ApiKey', 'Credential', 'BearerToken', 'ClientId', 'ClientSecret', 'TokenUri', 'Scope', 'Header', 'TimeoutSec', 'Proxy', 'ProxyCredential', 'SkipCertificateCheck', 'MaxRetries', 'Persist', 'PassThru')) {
            $check.ParameterNames | Should -Contain $name
        }
        $check.ParameterNames | Should -Not -Contain 'Service'
        $set.Text | Should -Match "\`$tcsContext\['Service'\] = \`$script:TcsOpenApiService"
        $set.Text | Should -Match 'Set-OpenApiContext @tcsContext'
    }

    It 'defaults -BaseUri to the first absolute server URL with variables filled in' {
        $servers = @(
            [pscustomobject]@{ Url = '/relative'; Variables = $null },
            [pscustomobject]@{ Url = 'https://{region}.example.com/v1'; Variables = [ordered]@{ region = [pscustomobject]@{ Default = 'eu'; Enum = @('eu', 'us') } } }
        )
        $set = @(ConvertTo-TestConnection -Server $servers)[0]
        $set.Text | Should -Match "\`$BaseUri = 'https://eu.example.com/v1'"
        $set.Text | Should -Not -Match 'Mandatory'
    }

    It 'makes -BaseUri mandatory without an absolute server URL' {
        $set = @(ConvertTo-TestConnection -Server @([pscustomobject]@{ Url = '/api'; Variables = $null }))[0]
        $set.Text | Should -Match '\[Parameter\(Mandatory = \$true\)\]\s+\[string\]\s+\$BaseUri,'
        $set.ConnectExample | Should -Match '-BaseUri'
    }

    It 'passes -Persisted through Remove and calls the engine with the service' {
        $remove = @(ConvertTo-TestConnection -Server @())[2]
        $remove.Text | Should -Match 'Remove-OpenApiContext @tcsContext'
        $remove.Text | Should -Match 'SupportsShouldProcess'
        @(ConvertTo-TestConnection -Server @())[1].Text | Should -Match 'Get-OpenApiContext -Service \$script:TcsOpenApiService'
    }
}
