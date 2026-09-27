BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Add-OpenApiFinding' {
    It 'adds a finding with the documented shape' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null -SourceVersion '3.0.0'
            Add-OpenApiFinding -Context $context -Severity Warning -Code 'OA010' -Pointer '/paths/~1a/get' -Message 'm' -Operation 'getA'
            $finding = $context.Findings[0]
            $finding.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Finding'
            @($finding.PSObject.Properties.Name) | Should -Be @('Severity', 'Code', 'Pointer', 'Message', 'Operation')
            $finding.Severity | Should -Be 'Warning'
            $finding.Operation | Should -Be 'getA'
        }
    }

    It 'defaults Operation to the operation being normalised, and to null outside one' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null
            Add-OpenApiFinding -Context $context -Severity Error -Code 'OA021' -Pointer '/a' -Message 'm'
            $context.CurrentOperation = 'op1'
            Add-OpenApiFinding -Context $context -Severity Error -Code 'OA021' -Pointer '/b' -Message 'm'
            Add-OpenApiFinding -Context $context -Severity Error -Code 'OA021' -Pointer '/c' -Message 'm' -Operation $null
            $context.Findings[0].Operation | Should -BeNullOrEmpty
            $context.Findings[1].Operation | Should -Be 'op1'
            $context.Findings[2].Operation | Should -BeNullOrEmpty
        }
    }

    It 'adds each code, pointer and operation once' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null
            1..3 | ForEach-Object { Add-OpenApiFinding -Context $context -Severity Information -Code 'OA022' -Pointer '/x' -Message 'm' }
            Add-OpenApiFinding -Context $context -Severity Information -Code 'OA022' -Pointer '/x' -Message 'm' -Operation 'other'
            $context.Findings.Count | Should -Be 2
        }
    }

    It 'maps converted Swagger 2.0 pointers back to definitions and securityDefinitions' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null -SourceVersion '2.0'
            Add-OpenApiFinding -Context $context -Severity Error -Code 'OA021' -Pointer '/components/schemas/Pet/properties/a' -Message 'm'
            Add-OpenApiFinding -Context $context -Severity Warning -Code 'OA030' -Pointer '/components/securitySchemes/x' -Message 'm'
            $context.Findings[0].Pointer | Should -BeExactly '/definitions/Pet/properties/a'
            $context.Findings[1].Pointer | Should -BeExactly '/securityDefinitions/x'
        }
    }

    It 'rejects unknown severities' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root $null
            { Add-OpenApiFinding -Context $context -Severity Fatal -Code 'X' -Pointer '' -Message 'm' } | Should -Throw
        }
    }
}
