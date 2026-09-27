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

Describe 'Import-OpenApiHttpAssembly' {
    It 'makes the System.Net.Http types available' {
        InModuleScope -ModuleName tcs.openapi {
            { Import-OpenApiHttpAssembly } | Should -Not -Throw
            'System.Net.Http.HttpClient' -as [type] | Should -Not -BeNullOrEmpty
        }
    }

    It 'enables TLS 1.2 on Windows PowerShell' -Skip:($PSVersionTable.PSEdition -eq 'Core') {
        InModuleScope -ModuleName tcs.openapi {
            Import-OpenApiHttpAssembly
            ([System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]::Tls12) | Should -Be ([System.Net.SecurityProtocolType]::Tls12)
        }
    }
}
