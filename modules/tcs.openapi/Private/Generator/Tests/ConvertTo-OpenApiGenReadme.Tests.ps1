BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenReadme' {
    It 'lists the commands sorted, with escaped summaries' {
        $document = New-TestDocument -Title 'Shop' -Version '2.0' -Description 'The shop API.'
        $functions = @(
            [pscustomobject]@{ Name = 'Set-ShopContext'; Method = $null; Path = $null; Summary = 'Set the connection.' },
            [pscustomobject]@{ Name = 'Get-ShopOrder'; Method = 'GET'; Path = '/orders'; Summary = "a | b`nc" }
        )
        $text = InModuleScope tcs.openapi -Parameters @{ Document = $document; Functions = $functions } {
            param($Document, $Functions)
            $option = Resolve-OpenApiGenOption -ModuleName 'Shop' -OutputPath '/out' -NounPrefix 'Shop' -GeneratorVersion '1.2.3'
            $template = (Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates'))['README.md']
            ConvertTo-OpenApiGenReadme -Option $option -Document $Document -Function $Functions -ConnectExample ' -BaseUri x' -Template $template
        }
        $text | Should -Match '(?m)^# Shop$'
        $text | Should -Match 'The shop API\.'
        $text | Should -Match 'tcs.openapi\) 1.2.3'
        $text | Should -Match 'Set-ShopContext -BaseUri x'
        $rows = @($text -split "`n" | Where-Object -FilterScript { $_.StartsWith('| `') })
        $rows[0] | Should -BeExactly '| `Get-ShopOrder` | GET | `/orders` | a \| b c |'
        $rows[1] | Should -BeExactly '| `Set-ShopContext` | - | - | Set the connection. |'
    }
}
