BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenTemplate' {
    It 'reads every template of the module' {
        $templates = InModuleScope tcs.openapi { Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates') }
        @($templates.Keys | Sort-Object) | Should -Be @('Function.ps1', 'Get-Context.ps1', 'Module.psd1', 'Module.psm1', 'Overrides.ps1', 'README.md', 'Remove-Context.ps1', 'Set-Context.ps1')
    }

    It 'normalises line endings to LF' {
        $folder = Join-Path -Path $TestDrive -ChildPath 'templates'
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path -Path $folder -ChildPath 'A.txt.template'), "a`r`nb")
        $templates = InModuleScope tcs.openapi -Parameters @{ Folder = $folder } { param($Folder) Get-OpenApiGenTemplate -Path $Folder }
        $templates['A.txt'] | Should -BeExactly "a`nb"
    }
}
