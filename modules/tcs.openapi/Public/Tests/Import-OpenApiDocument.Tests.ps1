BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../tcs.openapi.psd1') -Force
    $script:fixtures = (Resolve-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '../../../../tests/Fixtures')).ProviderPath
    $script:petstoreJson = Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.json'
    $script:petstoreYaml = Join-Path -Path $script:fixtures -ChildPath 'document-petstore-3.0.yaml'
}

Describe 'Import-OpenApiDocument' {
    Context 'Help' {
        It 'has a synopsis, a description, parameter help and an example' {
            $help = Get-Help -Name Import-OpenApiDocument -Full
            $help.Synopsis | Should -Not -BeNullOrEmpty
            $help.Description | Should -Not -BeNullOrEmpty
            @($help.Examples.Example).Count | Should -BeGreaterThan 0
            foreach ($name in 'Path', 'Uri', 'InputObject') {
                ($help.Parameters.Parameter | Where-Object Name -EQ $name).Description | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context '-Path' {
        It 'returns the document model' {
            $model = Import-OpenApiDocument -Path $script:petstoreJson
            $model.PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Document'
            $model.Title | Should -Be 'Petstore'
            $model.Operations.Count | Should -Be 6
            $model.Operations[0].PSObject.TypeNames | Should -Contain 'Tcs.OpenApi.Operation'
        }

        It 'accepts files from the pipeline' {
            $model = Get-Item -Path $script:petstoreJson | Import-OpenApiDocument
            $model.Title | Should -Be 'Petstore'
        }

        It 'throws for a missing file' {
            { Import-OpenApiDocument -Path (Join-Path -Path $TestDrive -ChildPath 'missing.json') -ErrorAction Stop } | Should -Throw
        }
    }

    Context '-InputObject' {
        It 'reads a JSON string' {
            $text = Get-Content -Path $script:petstoreJson -Raw
            (Import-OpenApiDocument -InputObject $text).Title | Should -Be 'Petstore'
        }

        It 'throws for invalid JSON' {
            { Import-OpenApiDocument -InputObject '{"openapi":' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*not valid JSON*'
        }

        It 'throws OpenApi.UnsupportedVersion (OA001) for an unsupported version' {
            $thrown = $null
            try {
                Import-OpenApiDocument -InputObject '{"openapi":"3.2.0","paths":{}}' -ErrorAction Stop
            }
            catch {
                $thrown = $_
            }
            $thrown.FullyQualifiedErrorId | Should -BeLike 'OpenApi.UnsupportedVersion*'
            $thrown.Exception.Message | Should -BeLike "*'3.2.0' is not supported*"
        }

        It 'returns the model for documents with other problems' {
            $model = Import-OpenApiDocument -InputObject '{"openapi":"3.0.0","info":{"title":"t","version":"1"}}'
            $model.Findings[0].Code | Should -Be 'OA002'
        }
    }

    Context '-Uri' {
        It 'downloads the document and resolves relative servers against the URL' {
            $bytes = [System.IO.File]::ReadAllBytes($script:petstoreJson)
            Mock -ModuleName tcs.openapi Invoke-WebRequest {
                [pscustomobject]@{ RawContentStream = New-Object -TypeName System.IO.MemoryStream -ArgumentList (, $bytes); Content = '' }
            }.GetNewClosure()
            $model = Import-OpenApiDocument -Uri 'https://petstore.example.com/spec/openapi.json'
            $model.Title | Should -Be 'Petstore'
            $model.Servers[1].Url | Should -Be 'https://petstore.example.com/v1'
            Should -Invoke -ModuleName tcs.openapi Invoke-WebRequest -Times 1
        }

        It 'throws when the download fails' {
            Mock -ModuleName tcs.openapi Invoke-WebRequest { throw 'Name resolution failed' }
            { Import-OpenApiDocument -Uri 'https://nowhere.example.com/openapi.json' -ErrorAction Stop } | Should -Throw -ExpectedMessage '*Name resolution failed*'
        }
    }

    Context 'YAML' {
        It 'throws a clear error when powershell-yaml is not available' {
            Mock -ModuleName tcs.openapi Get-OpenApiYamlConverter { }
            $thrown = $null
            try {
                Import-OpenApiDocument -Path $script:petstoreYaml -ErrorAction Stop
            }
            catch {
                $thrown = $_
            }
            $thrown.FullyQualifiedErrorId | Should -BeLike 'OpenApi.YamlNotSupported*'
            $thrown.Exception.Message | Should -BeLike '*Install-Module powershell-yaml*'
        }

        It 'uses ConvertFrom-Yaml when it is available and gives the same model as the JSON copy' {
            $seen = @{}
            $jsonText = Get-Content -Path $script:petstoreJson -Raw
            $parsed = & (Get-Module -Name tcs.openapi) { param($Text) ConvertFrom-OpenApiJson -Text $Text } $jsonText
            # Stand-in for powershell-yaml: records its arguments and returns the parsed equivalent of the YAML file
            New-Item -Path 'Function:\global:ConvertFrom-Yaml' -Value {
                param([string]$Yaml, [switch]$Ordered)
                $seen['Yaml'] = $Yaml
                $seen['Ordered'] = [bool]$Ordered
                $parsed
            }.GetNewClosure() -Force | Out-Null
            try {
                $fromYaml = Import-OpenApiDocument -Path $script:petstoreYaml
            }
            finally {
                Remove-Item -Path 'Function:\ConvertFrom-Yaml' -ErrorAction SilentlyContinue
            }
            $seen['Yaml'] | Should -BeExactly (Get-Content -Path $script:petstoreYaml -Raw)
            $seen['Ordered'] | Should -BeTrue
            $fromJson = Import-OpenApiDocument -Path $script:petstoreJson
            ($fromYaml | ConvertTo-Json -Depth 100 -Compress) | Should -BeExactly ($fromJson | ConvertTo-Json -Depth 100 -Compress)
        }
    }

    Context 'Swagger 2.0' {
        It 'returns an OpenAPI 3-shaped model' {
            $model = Import-OpenApiDocument -Path (Join-Path -Path $script:fixtures -ChildPath 'document-swagger-2.0.json')
            $model.SourceVersion | Should -Be '2.0'
            $model.Schemas['Pet'].RefName | Should -Be 'Pet'
            ($model.Operations | Where-Object OperationId -EQ 'addPet').RequestBody.Content[0].ContentType | Should -Be 'application/json'
        }
    }
}
