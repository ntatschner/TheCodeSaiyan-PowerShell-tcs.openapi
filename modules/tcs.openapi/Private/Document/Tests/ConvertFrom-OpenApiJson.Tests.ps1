BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiJson' {
    Context 'Auto engine' {
        It 'parses an object into ordered dictionaries' {
            InModuleScope tcs.openapi {
                $node = ConvertFrom-OpenApiJson -Text '{"openapi":"3.0.0","paths":{}}'
                $node['openapi'] | Should -Be '3.0.0'
                $node['paths'].Count | Should -Be 0
            }
        }

        It 'keeps keys that differ only in case' {
            InModuleScope tcs.openapi {
                $node = ConvertFrom-OpenApiJson -Text '{"properties":{"Id":{"type":"string"},"id":{"type":"integer"}}}'
                $node['properties']['Id']['type'] | Should -Be 'string'
                $node['properties']['id']['type'] | Should -Be 'integer'
            }
        }

        It 'keeps date-like strings as strings' {
            InModuleScope tcs.openapi {
                $node = ConvertFrom-OpenApiJson -Text '{"example":"2020-01-01T00:00:00Z"}'
                $node['example'] | Should -BeExactly '2020-01-01T00:00:00Z'
            }
        }

        It 'throws a clear error for invalid JSON' {
            InModuleScope tcs.openapi {
                { ConvertFrom-OpenApiJson -Text '{"a":' } | Should -Throw -ExpectedMessage 'The document is not valid JSON*'
            }
        }
    }

    Context 'ConvertFromJson engine' {
        It 'parses through ConvertFrom-Json' {
            InModuleScope tcs.openapi {
                $node = ConvertFrom-OpenApiJson -Text '{"a":{"b":[1,"x"]}}' -Engine ConvertFromJson
                $node['a']['b'][1] | Should -Be 'x'
            }
        }

        It 'reports keys that differ only in case as invalid on PowerShell 7' -Skip:($PSVersionTable.PSEdition -ne 'Core') {
            InModuleScope tcs.openapi {
                { ConvertFrom-OpenApiJson -Text '{"Id":1,"id":2}' -Engine ConvertFromJson } | Should -Throw -ExpectedMessage 'The document is not valid JSON*'
            }
        }

        It 'falls back to JavaScriptSerializer for keys that differ only in case on Windows PowerShell' -Skip:($PSVersionTable.PSEdition -eq 'Core') {
            InModuleScope tcs.openapi {
                $node = ConvertFrom-OpenApiJson -Text '{"Id":1,"id":2}' -Engine ConvertFromJson
                $node['Id'] | Should -Be 1
                $node['id'] | Should -Be 2
            }
        }
    }

    Context 'JavaScriptSerializer engine' {
        It 'keeps keys that differ only in case' -Skip:($PSVersionTable.PSEdition -eq 'Core') {
            InModuleScope tcs.openapi {
                $node = ConvertFrom-OpenApiJson -Text '{"Id":1,"id":[2]}' -Engine JavaScriptSerializer
                $node['Id'] | Should -Be 1
                $node['id'][0] | Should -Be 2
            }
        }
    }
}
