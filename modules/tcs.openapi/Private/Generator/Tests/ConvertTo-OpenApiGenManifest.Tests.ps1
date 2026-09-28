BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenManifest' {
    BeforeAll {
        function ConvertTo-TestManifest {
            param([string]$ModuleName = 'Shop.Api', [string[]]$FunctionName = @('Set-ShopContext', 'Get-ShopOrder'))
            $document = New-TestDocument -Title "Shop's API" -Version '2.0'
            InModuleScope tcs.openapi -Parameters @{ ModuleName = $ModuleName; FunctionName = $FunctionName; Document = $document } {
                param($ModuleName, $FunctionName, $Document)
                $option = Resolve-OpenApiGenOption -ModuleName $ModuleName -OutputPath '/out' -GeneratorVersion '1.2.3' -Author "O'Brien"
                $template = (Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates'))['Module.psd1']
                ConvertTo-OpenApiGenManifest -Option $option -Document $Document -FunctionName $FunctionName -Template $template
            }
        }
    }

    It 'renders a valid manifest with tcs.openapi as a required module at the generator version' {
        $text = ConvertTo-TestManifest
        $path = Join-Path -Path $TestDrive -ChildPath 'm.psd1'
        [System.IO.File]::WriteAllText($path, $text)
        $data = Import-PowerShellDataFile -Path $path
        $data.RootModule | Should -Be 'Shop.Api.psm1'
        $data.ModuleVersion | Should -Be '0.1.0'
        $data.Author | Should -Be "O'Brien"
        $data.RequiredModules[0].ModuleName | Should -Be 'tcs.openapi'
        $data.RequiredModules[0].ModuleVersion | Should -Be '1.2.3'
        $data.FunctionsToExport | Should -Be @('Get-ShopOrder', 'Set-ShopContext')
        $data.CompatiblePSEditions | Should -Be @('Desktop', 'Core')
        $data.Description | Should -Match "Shop's API \(API version 2.0\)"
    }

    It 'derives a stable GUID from the module name' {
        $first = [regex]::Match((ConvertTo-TestManifest), "GUID\s+= '([^']+)'").Groups[1].Value
        $second = [regex]::Match((ConvertTo-TestManifest), "GUID\s+= '([^']+)'").Groups[1].Value
        $other = [regex]::Match((ConvertTo-TestManifest -ModuleName 'Other'), "GUID\s+= '([^']+)'").Groups[1].Value
        $first | Should -Be $second
        $first | Should -Not -Be $other
        [guid]$first | Should -BeOfType [guid]
        $first.Substring(14, 1) | Should -Be '5'
    }

    It 'takes ProjectUri and LicenseUri from the document when they are web URLs' {
        $document = New-TestDocument -Title 'Shop' -ExternalDocsUrl 'https://docs.example.com' -ContactUrl 'https://example.com/support' -LicenseUrl 'https://example.com/license'
        $text = InModuleScope tcs.openapi -Parameters @{ Document = $document } {
            param($Document)
            $option = Resolve-OpenApiGenOption -ModuleName 'Shop' -OutputPath '/out' -GeneratorVersion '1.2.3'
            ConvertTo-OpenApiGenManifest -Option $option -Document $Document -FunctionName @('Get-ShopOrder') -Template (Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates'))['Module.psd1']
        }
        $data = & ([scriptblock]::Create($text))
        $data.PrivateData.PSData.ProjectUri | Should -Be 'https://docs.example.com'
        $data.PrivateData.PSData.LicenseUri | Should -Be 'https://example.com/license'

        $document = New-TestDocument -Title 'Shop' -ContactUrl 'https://example.com/support' -LicenseUrl 'mailto:x@example.com'
        $text = InModuleScope tcs.openapi -Parameters @{ Document = $document } {
            param($Document)
            $option = Resolve-OpenApiGenOption -ModuleName 'Shop' -OutputPath '/out' -GeneratorVersion '1.2.3'
            ConvertTo-OpenApiGenManifest -Option $option -Document $Document -FunctionName @('Get-ShopOrder') -Template (Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates'))['Module.psd1']
        }
        $data = & ([scriptblock]::Create($text))
        $data.PrivateData.PSData.ProjectUri | Should -Be 'https://example.com/support'
        $data.PrivateData.PSData.Keys | Should -Not -Contain 'LicenseUri'
        (ConvertTo-TestManifest) | Should -Not -Match 'ProjectUri|LicenseUri'
    }

    It 'renders an empty export list' {
        { [scriptblock]::Create((ConvertTo-TestManifest -FunctionName @())) } | Should -Not -Throw
    }
}
