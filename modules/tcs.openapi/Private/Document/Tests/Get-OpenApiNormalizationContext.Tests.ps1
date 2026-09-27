BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiNormalizationContext' {
    It 'creates empty, case-sensitive state for one run' {
        InModuleScope tcs.openapi {
            $context = Get-OpenApiNormalizationContext -Root @{ a = 1 } -SourceVersion '3.0.3'
            $context.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.NormalizationContext'
            $context.SourceVersion | Should -Be '3.0.3'
            $context.Findings.Count | Should -Be 0
            $context.ExternalRefHits | Should -Be 0
            $context.CurrentOperation | Should -BeNullOrEmpty
            $context.SchemaCache.Comparer | Should -Be ([System.StringComparer]::Ordinal)
            [void]$context.SchemaStack.Add('/a')
            $context.SchemaStack.Contains('/A') | Should -BeFalse
        }
    }

    It 'gives every run its own state' {
        InModuleScope tcs.openapi {
            $first = Get-OpenApiNormalizationContext -Root $null
            $second = Get-OpenApiNormalizationContext -Root $null
            $first.Findings.Add('x')
            $second.Findings.Count | Should -Be 0
        }
    }
}
