BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenVersion' {
    It 'reads the version from the tcs.openapi manifest' {
        $expected = (Import-PowerShellDataFile -Path (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1')).ModuleVersion
        InModuleScope tcs.openapi { Get-OpenApiGenVersion -ModuleRoot $script:TcsOpenApiModuleRoot } | Should -Be $expected
    }

    It 'reads another manifest folder' {
        $folder = Join-Path -Path $TestDrive -ChildPath 'fake'
        New-Item -Path $folder -ItemType Directory -Force | Out-Null
        Set-Content -Path (Join-Path -Path $folder -ChildPath 'tcs.openapi.psd1') -Value "@{ ModuleVersion = '9.8.7' }"
        InModuleScope tcs.openapi -Parameters @{ Folder = $folder } { param($Folder) Get-OpenApiGenVersion -ModuleRoot $Folder } | Should -Be '9.8.7'
    }
}
