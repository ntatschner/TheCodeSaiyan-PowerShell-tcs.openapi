BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiDocumentVersion' {
    It 'detects <Text> as <Family>' -TestCases @(
        @{ Text = '{"openapi":"3.0.0"}'; Family = '3.0'; SourceVersion = '3.0.0' }
        @{ Text = '{"openapi":"3.0.3"}'; Family = '3.0'; SourceVersion = '3.0.3' }
        @{ Text = '{"openapi":"3.1.0"}'; Family = '3.1'; SourceVersion = '3.1.0' }
        @{ Text = '{"openapi":"3.1.1"}'; Family = '3.1'; SourceVersion = '3.1.1' }
        @{ Text = '{"swagger":"2.0"}'; Family = '2.0'; SourceVersion = '2.0' }
        @{ Text = '{"swagger":2.0}'; Family = '2.0'; SourceVersion = '2.0' }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Text = $Text; Family = $Family; SourceVersion = $SourceVersion } {
            param($Text, $Family, $SourceVersion)
            $result = Get-OpenApiDocumentVersion -Root (ConvertFrom-OpenApiJson -Text $Text)
            $result.Supported | Should -BeTrue
            $result.Family | Should -Be $Family
            $result.SourceVersion | Should -Be $SourceVersion
        }
    }

    It 'rejects <Text>' -TestCases @(
        @{ Text = '{"openapi":"3.2.0"}'; Pointer = '/openapi' }
        @{ Text = '{"openapi":"2.0"}'; Pointer = '/openapi' }
        @{ Text = '{"openapi":"3.0"}'; Pointer = '/openapi' }
        @{ Text = '{"swagger":"1.2"}'; Pointer = '/swagger' }
        @{ Text = '{"info":{}}'; Pointer = '' }
        @{ Text = '[1,2]'; Pointer = '' }
        @{ Text = '"text"'; Pointer = '' }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Text = $Text; Pointer = $Pointer } {
            param($Text, $Pointer)
            $result = Get-OpenApiDocumentVersion -Root (ConvertFrom-OpenApiJson -Text $Text)
            $result.Supported | Should -BeFalse
            $result.Pointer | Should -BeExactly $Pointer
            $result.Message | Should -Not -BeNullOrEmpty
        }
    }
}
