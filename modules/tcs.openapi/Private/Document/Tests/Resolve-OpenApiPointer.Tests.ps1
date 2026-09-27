BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Resolve-OpenApiPointer' {
    BeforeAll {
        $script:root = InModuleScope tcs.openapi {
            ConvertFrom-OpenApiJson -Text '{"components":{"schemas":{"a/b~c":{"type":"string"},"with space":{"type":"integer"},"Pet":{"type":"object"}}},"list":[10,20],"Case":1,"case":2}'
        }
    }

    It 'resolves a plain pointer and returns the canonical pointer' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            $result = Resolve-OpenApiPointer -Root $Root -Reference '#/components/schemas/Pet'
            $result.Found | Should -BeTrue
            $result.Value['type'] | Should -Be 'object'
            $result.Pointer | Should -BeExactly '/components/schemas/Pet'
        }
    }

    It 'unescapes ~1 and ~0 (in that order)' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            $result = Resolve-OpenApiPointer -Root $Root -Reference '#/components/schemas/a~1b~0c'
            $result.Found | Should -BeTrue
            $result.Pointer | Should -BeExactly '/components/schemas/a~1b~0c'
        }
    }

    It 'percent-decodes the fragment' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            (Resolve-OpenApiPointer -Root $Root -Reference '#/components/schemas/with%20space').Value['type'] | Should -Be 'integer'
        }
    }

    It 'indexes arrays' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            (Resolve-OpenApiPointer -Root $Root -Reference '#/list/1').Value | Should -Be 20
            (Resolve-OpenApiPointer -Root $Root -Reference '#/list/2').Found | Should -BeFalse
        }
    }

    It 'is case-sensitive' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            (Resolve-OpenApiPointer -Root $Root -Reference '#/Case').Value | Should -Be 1
            (Resolve-OpenApiPointer -Root $Root -Reference '#/case').Value | Should -Be 2
            (Resolve-OpenApiPointer -Root $Root -Reference '#/components/schemas/pet').Found | Should -BeFalse
        }
    }

    It 'maps #/definitions to #/components/schemas when the tree has no definitions' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            $result = Resolve-OpenApiPointer -Root $Root -Reference '#/definitions/Pet'
            $result.Found | Should -BeTrue
            $result.Pointer | Should -BeExactly '/components/schemas/Pet'
        }
    }

    It 'returns not found for external and malformed references' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            (Resolve-OpenApiPointer -Root $Root -Reference 'other.json#/Pet').Found | Should -BeFalse
            (Resolve-OpenApiPointer -Root $Root -Reference '#components').Found | Should -BeFalse
            (Resolve-OpenApiPointer -Root $Root -Reference '#/nope').Found | Should -BeFalse
        }
    }

    It 'resolves # to the root' {
        InModuleScope tcs.openapi -Parameters @{ Root = $script:root } {
            param($Root)
            $result = Resolve-OpenApiPointer -Root $Root -Reference '#'
            $result.Found | Should -BeTrue
            $result.Pointer | Should -BeExactly ''
        }
    }
}
