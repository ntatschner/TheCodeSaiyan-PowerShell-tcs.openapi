BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Test-OpenApiMediaTypeSupport' {
    It 'supports <ContentType>' -TestCases @(
        @{ ContentType = 'application/json' }
        @{ ContentType = 'application/json; charset=utf-8' }
        @{ ContentType = 'application/merge-patch+json' }
        @{ ContentType = 'text/json' }
        @{ ContentType = 'application/x-www-form-urlencoded' }
        @{ ContentType = 'multipart/form-data' }
        @{ ContentType = 'application/octet-stream' }
        @{ ContentType = 'text/plain' }
        @{ ContentType = 'text/csv' }
        @{ ContentType = '*/*' }
    ) {
        InModuleScope tcs.openapi -Parameters @{ ContentType = $ContentType } {
            param($ContentType)
            $schema = Get-OpenApiBlankSchema
            $schema.Type = 'object'
            Test-OpenApiMediaTypeSupport -ContentType $ContentType -Schema $schema | Should -BeTrue
        }
    }

    It 'supports other media types with a binary schema or without a schema' {
        InModuleScope tcs.openapi {
            $schema = Get-OpenApiBlankSchema
            $schema.Type = 'string'
            $schema.Format = 'binary'
            Test-OpenApiMediaTypeSupport -ContentType 'image/png' -Schema $schema | Should -BeTrue
            Test-OpenApiMediaTypeSupport -ContentType 'application/pdf' -Schema $null | Should -BeTrue
        }
    }

    It 'does not support structured non-JSON media types such as XML' {
        InModuleScope tcs.openapi {
            $schema = Get-OpenApiBlankSchema
            $schema.Type = 'object'
            Test-OpenApiMediaTypeSupport -ContentType 'application/xml' -Schema $schema | Should -BeFalse
            Test-OpenApiMediaTypeSupport -ContentType 'application/x-yaml' -Schema $schema | Should -BeFalse
        }
    }
}
