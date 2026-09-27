BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../tcs.openapi.psd1') -Force
    $script:fixtures = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '../../../../tests/Fixtures')).ProviderPath
}

Describe 'Test-OpenApiDocument' {
    Context 'Help' {
        It 'has a synopsis, a description, parameter help and an example' {
            $help = Get-Help -Name Test-OpenApiDocument -Full
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
            foreach ($name in 'Path', 'Uri', 'InputObject', 'Document') {
                ($help.Parameters.Parameter | Where-Object Name -EQ $name).Description | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context 'Findings' {
        It 'returns findings with the documented shape' {
            $findings = @(Test-OpenApiDocument -Path (Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.json'))
            $findings.Count | Should -Be 3
            $findings[0].PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Finding'
            @($findings[0].PSObject.Properties.Name) | Should -Be @('Severity', 'Code', 'Pointer', 'Message', 'Operation')
        }

        It 'returns <Code> for <Fixture>' -TestCases @(
            @{ Fixture = 'document-petstore-3.0.json'; Code = 'OA010' }
            @{ Fixture = 'document-petstore-3.0.json'; Code = 'OA051' }
            @{ Fixture = 'document-petstore-3.0.json'; Code = 'OA060' }
            @{ Fixture = 'document-path-parameters.json'; Code = 'OA011' }
            @{ Fixture = 'document-external-ref.json'; Code = 'OA020' }
            @{ Fixture = 'document-external-ref.json'; Code = 'OA021' }
            @{ Fixture = 'document-circular.json'; Code = 'OA022' }
            @{ Fixture = 'document-openapi-3.1.json'; Code = 'OA030' }
            @{ Fixture = 'document-swagger-2.0.json'; Code = 'OA030' }
            @{ Fixture = 'document-openapi-3.1.json'; Code = 'OA031' }
            @{ Fixture = 'document-composition.json'; Code = 'OA050' }
        ) {
            $findings = @(Test-OpenApiDocument -Path (Join-Path -Path $script:fixtures -ChildPath $Fixture))
            $finding = $findings | Where-Object Code -EQ $Code | Select-Object -First 1
            $finding | Should -Not -BeNullOrEmpty
            $finding.Pointer | Should -Match '^/'
            $finding.Message | Should -Not -BeNullOrEmpty
            $finding.Severity | Should -BeIn @('Error', 'Warning', 'Information')
        }

        It 'returns OA001 instead of throwing for an unsupported version' {
            $findings = @(Test-OpenApiDocument -InputObject '{"swagger":"1.2"}')
            $findings.Count | Should -Be 1
            $findings[0].Code | Should -Be 'OA001'
            $findings[0].Severity | Should -Be 'Error'
            $findings[0].Pointer | Should -BeExactly '/swagger'
        }

        It 'returns OA001 for JSON that is not a document object' {
            (Test-OpenApiDocument -InputObject '[1,2,3]').Code | Should -Be 'OA001'
        }

        It 'returns OA002 for missing paths' {
            (Test-OpenApiDocument -InputObject '{"openapi":"3.0.3","info":{"title":"t","version":"1"}}').Code | Should -Be 'OA002'
        }

        It 'returns nothing for a clean document' {
            @(Test-OpenApiDocument -InputObject '{"openapi":"3.0.3","info":{"title":"t","version":"1"},"paths":{"/a":{"get":{"operationId":"a","responses":{"200":{"description":"ok"}}}}}}').Count | Should -Be 0
        }

        It 'turns unexpected normalisation failures into an OA001 finding' {
            Mock -ModuleName tcs.openapi ConvertTo-OpenApiDocumentModel { throw 'boom' }
            $findings = @(Test-OpenApiDocument -InputObject '{"openapi":"3.0.3","paths":{}}')
            $findings[0].Code | Should -Be 'OA001'
            $findings[0].Message | Should -BeLike '*boom*'
        }
    }

    Context 'Input' {
        It 'returns the findings of a model passed with -Document' {
            $model = Import-OpenApiDocument -Path (Join-Path -Path $script:fixtures -ChildPath 'document-circular.json')
            @(Test-OpenApiDocument -Document $model).Count | Should -Be $model.Findings.Count
        }

        It 'reads a URL' {
            Mock -ModuleName tcs.openapi Invoke-WebRequest { [pscustomobject]@{ RawContentStream = $null; Content = '{"openapi":"9"}' } }
            (Test-OpenApiDocument -Uri 'https://api.example.com/openapi.json').Code | Should -Be 'OA001'
        }

        It 'accepts files from the pipeline' {
            @(Get-Item -Path (Join-Path -Path $script:fixtures -ChildPath 'document-circular.json') | Test-OpenApiDocument).Count | Should -Be 2
        }

        It 'throws only for unreadable input' {
            { Test-OpenApiDocument -Path (Join-Path -Path $TestDrive -ChildPath 'missing.json') -ErrorAction Stop } | Should -Throw
            { Test-OpenApiDocument -InputObject '{"a":' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*not valid JSON*'
        }
    }
}
