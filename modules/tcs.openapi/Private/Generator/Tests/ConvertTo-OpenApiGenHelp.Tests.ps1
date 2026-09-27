BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenHelp' {
    It 'renders sections with keyword and text indentation' {
        $help = InModuleScope tcs.openapi {
            ConvertTo-OpenApiGenHelp -Section @(@{ Keyword = 'SYNOPSIS'; Text = 'Short.' }, @{ Keyword = 'PARAMETER'; Argument = 'Id'; Text = "Line 1`r`nLine 2" })
        }
        $help | Should -BeExactly "    .SYNOPSIS`n        Short.`n`n    .PARAMETER Id`n        Line 1`n        Line 2"
    }

    It 'breaks up comment markers and keyword-like lines' {
        $help = InModuleScope tcs.openapi { ConvertTo-OpenApiGenHelp -Section @(@{ Keyword = 'DESCRIPTION'; Text = "a #> b <# c`n.NOTES x`n.NET is fine" }) }
        $help | Should -Not -Match '#>'
        $help | Should -Not -Match '<#'
        $help | Should -Match '\. NOTES x'
        $help | Should -Match '        \.NET is fine'
    }

    It 'trims trailing spaces, turns tabs into spaces and collapses blank lines' {
        $help = InModuleScope tcs.openapi { ConvertTo-OpenApiGenHelp -Section @(@{ Keyword = 'DESCRIPTION'; Text = "a  `n`n`n`tb" }) }
        $help | Should -BeExactly "    .DESCRIPTION`n        a`n`n            b"
    }

    It 'produces help that Get-Help reads' {
        $help = InModuleScope tcs.openapi {
            ConvertTo-OpenApiGenHelp -Section @(@{ Keyword = 'SYNOPSIS'; Text = 'Gets a thing.' }, @{ Keyword = 'PARAMETER'; Argument = 'Name'; Text = 'The name.' }, @{ Keyword = 'EXAMPLE'; Text = 'Get-HelpProbe -Name x' })
        }
        $source = "function Get-HelpProbe {`n    <#`n$help`n    #>`n    [CmdletBinding()]`n    param([string]`$Name)`n}"
        . ([scriptblock]::Create($source))
        $info = Get-Help -Name Get-HelpProbe -Full
        $info.Synopsis | Should -Be 'Gets a thing.'
        ($info.parameters.parameter | Where-Object -FilterScript { $_.name -eq 'Name' }).description.Text | Should -Be 'The name.'
    }
}
