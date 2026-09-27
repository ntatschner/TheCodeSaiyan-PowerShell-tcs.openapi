BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'Resolve-OpenApiGenVerb' {
    It 'maps <Word> on <Method> to <Verb>' -TestCases @(
        @{ Word = 'get'; Method = 'GET'; Verb = 'Get'; IsList = $false }
        @{ Word = 'list'; Method = 'GET'; Verb = 'Get'; IsList = $true }
        @{ Word = 'search'; Method = 'POST'; Verb = 'Get'; IsList = $true }
        @{ Word = 'find'; Method = 'GET'; Verb = 'Get'; IsList = $true }
        @{ Word = 'create'; Method = 'POST'; Verb = 'New'; IsList = $false }
        @{ Word = 'add'; Method = 'POST'; Verb = 'New'; IsList = $false }
        @{ Word = 'update'; Method = 'PUT'; Verb = 'Set'; IsList = $false }
        @{ Word = 'update'; Method = 'PATCH'; Verb = 'Update'; IsList = $false }
        @{ Word = 'set'; Method = 'PATCH'; Verb = 'Update'; IsList = $false }
        @{ Word = 'replace'; Method = 'POST'; Verb = 'Set'; IsList = $false }
        @{ Word = 'update'; Method = 'POST'; Verb = 'Update'; IsList = $false }
        @{ Word = 'delete'; Method = 'DELETE'; Verb = 'Remove'; IsList = $false }
        @{ Word = 'remove'; Method = 'POST'; Verb = 'Remove'; IsList = $false }
        @{ Word = 'start'; Method = 'POST'; Verb = 'Start'; IsList = $false }
        @{ Word = 'disconnect'; Method = 'POST'; Verb = 'Disconnect'; IsList = $false }
        @{ Word = 'unregister'; Method = 'POST'; Verb = 'Unregister'; IsList = $false }
        @{ Word = 'show'; Method = 'GET'; Verb = 'Get'; IsList = $false }
        @{ Word = 'Validate'; Method = 'POST'; Verb = 'Test'; IsList = $false }
    ) {
        param($Word, $Method, $Verb, $IsList)
        $result = InModuleScope tcs.openapi -Parameters @{ Word = $Word; Method = $Method } { param($Word, $Method) Resolve-OpenApiGenVerb -Word $Word -Method $Method }
        $result.Verb | Should -BeExactly $Verb
        $result.IsList | Should -Be $IsList
    }

    It 'returns nothing for an unknown word' {
        InModuleScope tcs.openapi { Resolve-OpenApiGenVerb -Word 'upload' -Method 'POST' } | Should -BeNullOrEmpty
        InModuleScope tcs.openapi { Resolve-OpenApiGenVerb -Word 'pets' -Method 'GET' } | Should -BeNullOrEmpty
    }

    It 'returns the method default <Verb> for <Method>' -TestCases @(
        @{ Method = 'GET'; Verb = 'Get' }, @{ Method = 'POST'; Verb = 'New' }, @{ Method = 'PUT'; Verb = 'Set' },
        @{ Method = 'PATCH'; Verb = 'Update' }, @{ Method = 'DELETE'; Verb = 'Remove' }, @{ Method = 'HEAD'; Verb = 'Test' },
        @{ Method = 'OPTIONS'; Verb = 'Get' }, @{ Method = 'trace'; Verb = 'Get' }
    ) {
        param($Method, $Verb)
        (InModuleScope tcs.openapi -Parameters @{ Method = $Method } { param($Method) Resolve-OpenApiGenVerb -Method $Method }).Verb | Should -BeExactly $Verb
    }

    It 'only returns approved verbs' {
        $approved = @(Get-Verb | ForEach-Object -Process { $_.Verb })
        foreach ($word in @('get', 'list', 'create', 'update', 'delete', 'start', 'stop', 'restart', 'enable', 'disable', 'approve', 'deny', 'import', 'export', 'test', 'invoke', 'send', 'reset', 'clear', 'copy', 'move', 'rename', 'sync', 'publish', 'register', 'unregister', 'connect', 'disconnect', 'run', 'check')) {
            $approved | Should -Contain (InModuleScope tcs.openapi -Parameters @{ Word = $word } { param($Word) Resolve-OpenApiGenVerb -Word $Word -Method 'POST' }).Verb
        }
    }
}
