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

Describe 'ConvertTo-OpenApiResponseText' {
    It 'decodes UTF-8 by default and removes a BOM' {
        InModuleScope -ModuleName tcs.openapi {
            $bytes = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes("h$([char]0x00E9)")
            ConvertTo-OpenApiResponseText -Bytes $bytes -ContentType 'application/json' | Should -BeExactly "h$([char]0x00E9)"
            ConvertTo-OpenApiResponseText -Bytes ([byte[]]@()) -ContentType $null | Should -BeExactly ''
        }
    }

    It 'uses the charset of the content type' {
        InModuleScope -ModuleName tcs.openapi {
            $bytes = [System.Text.Encoding]::Unicode.GetBytes('wide')
            ConvertTo-OpenApiResponseText -Bytes $bytes -ContentType 'text/plain; charset=utf-16' | Should -BeExactly 'wide'
            ConvertTo-OpenApiResponseText -Bytes ([System.Text.Encoding]::UTF8.GetBytes('ok')) -ContentType 'text/plain; charset=nonsense' | Should -BeExactly 'ok'
        }
    }
}
