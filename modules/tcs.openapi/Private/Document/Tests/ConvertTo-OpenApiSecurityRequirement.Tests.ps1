BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiSecurityRequirement' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Json)
                $context = Get-OpenApiNormalizationContext -Root (ConvertFrom-OpenApiJson -Text '{"components":{"securitySchemes":{"key":{},"oauth":{}}}}')
                $list = ConvertTo-OpenApiSecurityRequirement -Context $context -Requirement (ConvertFrom-OpenApiJson -Text $Json) -Pointer '/security'
                [pscustomobject]@{ List = $list; Findings = $context.Findings.ToArray() }
            }
        }
    }

    It 'converts requirements into maps of scheme name to scopes' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '[{"oauth":["a","b"]},{"key":[],"oauth":[]}]'
            $result.List.Count | Should -Be 2
            $result.List[0]['oauth'] | Should -Be @('a', 'b')
            @($result.List[1].Keys) | Should -Be @('key', 'oauth')
            , $result.List[1]['key'] | Should -BeOfType [string[]]
            $result.Findings.Count | Should -Be 0
        }
    }

    It 'keeps an empty list (no authentication) as an empty array' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $list = (& $Convert '[]').List
            , $list | Should -BeOfType [object[]]
            $list.Count | Should -Be 0
        }
    }

    It 'keeps an empty requirement (optional authentication) as an empty map' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $list = (& $Convert '[{}]').List
            $list.Count | Should -Be 1
            $list[0].Count | Should -Be 0
        }
    }

    It 'reports undefined schemes as OA021 warnings' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '[{"missing":[]}]'
            $result.Findings[0].Code | Should -Be 'OA021'
            $result.Findings[0].Severity | Should -Be 'Warning'
            $result.Findings[0].Pointer | Should -BeExactly '/security/0/missing'
        }
    }
}
