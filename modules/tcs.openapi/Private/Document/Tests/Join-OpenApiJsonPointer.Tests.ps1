BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Join-OpenApiJsonPointer' {
    It 'escapes ~ as ~0 and / as ~1' {
        InModuleScope tcs.openapi {
            Join-OpenApiJsonPointer -Pointer '/paths' -Segment '/pets/{id}', 'get' | Should -BeExactly '/paths/~1pets~1{id}/get'
            Join-OpenApiJsonPointer -Pointer '' -Segment 'a~/b' | Should -BeExactly '/a~0~1b'
        }
    }

    It 'keeps empty segments' {
        InModuleScope tcs.openapi {
            Join-OpenApiJsonPointer -Pointer '/x' -Segment '' | Should -BeExactly '/x/'
        }
    }
}
