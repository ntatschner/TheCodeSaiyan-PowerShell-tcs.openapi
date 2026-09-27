BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
    $script:fixtures = Join-Path -Path $PSScriptRoot -ChildPath '../../../../../tests/Fixtures'
}

Describe 'Get-OpenApiDocumentText' {
    It 'reads a JSON file' {
        InModuleScope tcs.openapi -Parameters @{ Fixtures = $script:fixtures } {
            param($Fixtures)
            $result = Get-OpenApiDocumentText -Path (Join-Path -Path $Fixtures -ChildPath 'document-petstore-3.0.json')
            $result.Text | Should -BeLike '*"openapi": "3.0.3"*'
            $result.Format | Should -Be 'Json'
            $result.Source | Should -BeLike '*document-petstore-3.0.json'
            $result.BaseUri | Should -BeNullOrEmpty
        }
    }

    It 'detects the format of other files from their content' {
        InModuleScope tcs.openapi -Parameters @{ Fixtures = $script:fixtures } {
            param($Fixtures)
            (Get-OpenApiDocumentText -Path (Join-Path -Path $Fixtures -ChildPath 'document-petstore-3.0.yaml')).Format | Should -Be 'Auto'
        }
    }

    It 'throws for a missing file' {
        InModuleScope tcs.openapi {
            { Get-OpenApiDocumentText -Path (Join-Path -Path $TestDrive -ChildPath 'missing.json') } | Should -Throw
        }
    }

    It 'throws for a folder' {
        InModuleScope tcs.openapi {
            { Get-OpenApiDocumentText -Path $TestDrive } | Should -Throw -ExpectedMessage '*is not a file*'
        }
    }

    It 'downloads a URL and decodes the raw bytes as UTF-8' {
        InModuleScope tcs.openapi {
            Mock Invoke-WebRequest {
                $bytes = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes('{"info":{"title":"Caf' + [char]0x00E9 + '"}}')
                [pscustomobject]@{ RawContentStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList (, $bytes); Content = 'ignored' }
            }
            $result = Get-OpenApiDocumentText -Uri 'https://api.example.com/openapi.json'
            $result.Text | Should -BeExactly ('{"info":{"title":"Caf' + [char]0x00E9 + '"}}')
            $result.BaseUri.AbsoluteUri | Should -Be 'https://api.example.com/openapi.json'
            $result.Format | Should -Be 'Auto'
            Should -Invoke Invoke-WebRequest -Times 1 -ParameterFilter { $Uri -eq 'https://api.example.com/openapi.json' -and $UseBasicParsing }
        }
    }

    It 'falls back to Content when there is no raw stream' {
        InModuleScope tcs.openapi {
            Mock Invoke-WebRequest { [pscustomobject]@{ RawContentStream = $null; Content = '{"a":1}' } }
            (Get-OpenApiDocumentText -Uri 'https://api.example.com/x').Text | Should -BeExactly '{"a":1}'
        }
    }

    It 'rejects relative URIs' {
        InModuleScope tcs.openapi {
            { Get-OpenApiDocumentText -Uri ([uri]::new('/relative', [System.UriKind]::Relative)) } | Should -Throw -ExpectedMessage '*must be absolute*'
        }
    }

    It 'wraps a string' {
        InModuleScope tcs.openapi {
            $result = Get-OpenApiDocumentText -InputObject '{}'
            $result.Text | Should -Be '{}'
            $result.Source | Should -Be 'InputObject'
        }
    }
}
