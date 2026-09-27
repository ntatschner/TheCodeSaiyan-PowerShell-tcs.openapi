BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiRawNode' {
    It 'converts PSCustomObject trees into case-sensitive ordered dictionaries' {
        InModuleScope tcs.openapi {
            $node = ConvertTo-OpenApiRawNode -InputObject ([pscustomobject]@{ b = 1; a = [pscustomobject]@{ c = @(1, 2) } })
            $node | Should -BeOfType System.Collections.Specialized.OrderedDictionary
            @($node.Keys) | Should -Be @('b', 'a')
            $node['a']['c'].GetType().FullName | Should -Be 'System.Object[]'
            $node['a']['c'].Count | Should -Be 2
            $node['B'] | Should -BeNullOrEmpty
        }
    }

    It 'converts any dictionary (JavaScriptSerializer / YAML shape) and stringifies keys' {
        InModuleScope tcs.openapi {
            $source = New-Object -TypeName 'System.Collections.Generic.Dictionary[object,object]'
            $source.Add(200, 'ok')
            $source.Add('Name', 'x')
            $source.Add('name', 'y')
            $node = ConvertTo-OpenApiRawNode -InputObject $source
            $node['200'] | Should -Be 'ok'
            $node['Name'] | Should -Be 'x'
            $node['name'] | Should -Be 'y'
        }
    }

    It 'keeps single-item and empty arrays as arrays' {
        InModuleScope tcs.openapi {
            $node = ConvertTo-OpenApiRawNode -InputObject @{ one = @('x'); none = @() }
            $node['one'].GetType().FullName | Should -Be 'System.Object[]'
            $node['one'].Count | Should -Be 1
            $node['none'].GetType().FullName | Should -Be 'System.Object[]'
            $node['none'].Count | Should -Be 0
        }
    }

    It 'turns DateTime values back into ISO 8601 strings' {
        InModuleScope tcs.openapi {
            $value = ConvertTo-OpenApiRawNode -InputObject ([datetime]::new(2020, 1, 2, 3, 4, 5, [System.DateTimeKind]::Utc))
            $value | Should -BeOfType [string]
            $value | Should -BeLike '2020-01-02T03:04:05*Z'
        }
    }

    It 'passes scalars and null through' {
        InModuleScope tcs.openapi {
            ConvertTo-OpenApiRawNode -InputObject $null | Should -BeNullOrEmpty
            ConvertTo-OpenApiRawNode -InputObject 'text' | Should -BeExactly 'text'
            ConvertTo-OpenApiRawNode -InputObject $true | Should -BeTrue
            ConvertTo-OpenApiRawNode -InputObject 1.5 | Should -Be 1.5
        }
    }

    It 'converts System.Text.Json elements' -Skip:($PSVersionTable.PSEdition -ne 'Core') {
        InModuleScope tcs.openapi {
            $document = [System.Text.Json.JsonDocument]::Parse('{"a":[1,2147483648,1.5,"s",true,false,null],"b":{}}')
            try {
                $node = ConvertTo-OpenApiRawNode -InputObject $document.RootElement
            }
            finally {
                $document.Dispose()
            }
            $node['a'][0] | Should -BeOfType [int]
            $node['a'][1] | Should -BeOfType [long]
            $node['a'][2] | Should -BeOfType [double]
            $node['a'][3] | Should -BeExactly 's'
            $node['a'][4] | Should -BeTrue
            $node['a'][5] | Should -BeFalse
            $node['a'][6] | Should -BeNullOrEmpty
            $node['b'] | Should -BeOfType System.Collections.Specialized.OrderedDictionary
        }
    }
}
