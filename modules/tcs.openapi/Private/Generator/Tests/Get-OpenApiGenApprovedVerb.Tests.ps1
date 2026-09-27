BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Get-OpenApiGenApprovedVerb' {
    It 'returns only verbs that Get-Verb approves' {
        $approved = @(Get-Verb | ForEach-Object -Process { $_.Verb })
        $verbs = InModuleScope tcs.openapi { Get-OpenApiGenApprovedVerb }
        foreach ($verb in $verbs) {
            $approved | Should -Contain $verb
        }
    }

    It 'leaves out the verbs that Windows PowerShell 5.1 does not have' {
        $verbs = InModuleScope tcs.openapi { Get-OpenApiGenApprovedVerb }
        $verbs | Should -Not -Contain 'Build'
        $verbs | Should -Not -Contain 'Deploy'
        $verbs.Count | Should -Be 98
    }
}
