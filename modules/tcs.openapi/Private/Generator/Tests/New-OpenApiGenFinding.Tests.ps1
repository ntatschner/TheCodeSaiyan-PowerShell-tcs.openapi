BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'New-OpenApiGenFinding' {
    It 'builds the finding shape with the JSON pointer of the operation' {
        $operation = New-TestOperation -OperationId 'getPet' -Method GET -Path '/pets/{petId}'
        $finding = InModuleScope tcs.openapi -Parameters @{ Operation = $operation } {
            param($Operation)
            New-OpenApiGenFinding -Severity Warning -Code 'OA041' -Message 'renamed' -Operation $Operation -PointerSuffix '/parameters'
        }
        $finding.Severity | Should -Be 'Warning'
        $finding.Code | Should -Be 'OA041'
        $finding.Pointer | Should -Be '/paths/~1pets~1{petId}/get/parameters'
        $finding.Message | Should -Be 'renamed'
        $finding.Operation | Should -Be 'getPet'
        $finding.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Finding'
    }

    It 'escapes ~ in the path' {
        $operation = New-TestOperation -OperationId 'x' -Method POST -Path '/a~b'
        (InModuleScope tcs.openapi -Parameters @{ Operation = $operation } { param($Operation) New-OpenApiGenFinding -Severity Error -Code 'OA070' -Message 'm' -Operation $Operation }).Pointer | Should -Be '/paths/~1a~0b/post'
    }

    It 'allows a finding without an operation' {
        $finding = InModuleScope tcs.openapi { New-OpenApiGenFinding -Severity Information -Code 'OA040' -Message 'm' }
        $finding.Pointer | Should -Be ''
        $finding.Operation | Should -BeNullOrEmpty
    }
}
