BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'ConvertFrom-OpenApiSwagger2' {
    BeforeAll {
        $script:convert = InModuleScope tcs.openapi {
            {
                param([string]$Json, [uri]$BaseUri)
                ConvertFrom-OpenApiSwagger2 -Root (ConvertFrom-OpenApiJson -Text $Json) -BaseUri $BaseUri
            }
        }
    }

    It 'builds one server per scheme from host and basePath' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"swagger":"2.0","host":"api.example.com:8443","basePath":"/v2","schemes":["https","http"]}'
            @($result['servers'] | ForEach-Object { $_['url'] }) | Should -Be @('https://api.example.com:8443/v2', 'http://api.example.com:8443/v2')
            $result['openapi'] | Should -Be '3.0.3'
        }
    }

    It 'defaults the scheme to https and the basePath to /' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"host":"api.example.com"}')['servers'][0]['url'] | Should -Be 'https://api.example.com'
            (& $Convert '{"host":"api.example.com","basePath":"v1"}')['servers'][0]['url'] | Should -Be 'https://api.example.com/v1'
        }
    }

    It 'uses basePath alone without a host, or the host of the document URL' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            (& $Convert '{"basePath":"/api"}')['servers'][0]['url'] | Should -Be '/api'
            (& $Convert '{"basePath":"/api"}' 'http://localhost:8080/swagger.json')['servers'][0]['url'] | Should -Be 'http://localhost:8080/api'
        }
    }

    It 'moves definitions and securityDefinitions into components' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"definitions":{"Pet":{"type":"object"}},"securityDefinitions":{"b":{"type":"basic"}}}'
            $result['components']['schemas']['Pet']['type'] | Should -Be 'object'
            $result['components']['securitySchemes']['b']['scheme'] | Should -Be 'basic'
        }
    }

    It 'keeps info, tags, externalDocs, security and x- extensions' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"info":{"title":"t"},"tags":[{"name":"a"}],"externalDocs":{"url":"u"},"security":[{"b":[]}],"x-logo":{"url":"l"},"consumes":["application/json"]}'
            foreach ($key in 'info', 'tags', 'externalDocs', 'security', 'x-logo') {
                $result.Contains($key) | Should -BeTrue
            }
            $result.Contains('consumes') | Should -BeFalse
        }
    }

    It 'converts operations with the document consumes/produces and keeps path-item extensions' {
        InModuleScope tcs.openapi -Parameters @{ Convert = $script:convert } {
            param($Convert)
            $result = & $Convert '{"consumes":["application/xml"],"produces":["text/plain"],"paths":{"/a":{"x-note":"n","parameters":[{"name":"q","in":"query","type":"string"}],"post":{"parameters":[{"name":"body","in":"body","schema":{"type":"string"}}],"responses":{"200":{"description":"ok","schema":{"type":"string"}}}}}}}'
            $path = $result['paths']['/a']
            $path['x-note'] | Should -Be 'n'
            $path.Contains('parameters') | Should -BeFalse
            $path['post']['parameters'][0]['name'] | Should -Be 'q'
            @($path['post']['requestBody']['content'].Keys) | Should -Be @('application/xml')
            @($path['post']['responses']['200']['content'].Keys) | Should -Be @('text/plain')
        }
    }
}
