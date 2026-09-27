# End to end for the document-layer fixtures (OpenAPI 3.0, Swagger 2.0 and OpenAPI 3.1): each is imported,
# generated into TestDrive, imported with the real tcs.openapi and called against the test HTTP server.

BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/EndToEnd.ps1')

    $script:server = Start-TestHttpServer -Handler {
        param($Request)
        $key = "$($Request.Method) $($Request.Path)"
        switch -Regex ($key) {
            '^GET /v1/pets$' {
                if ($Request.RawUrl -match 'skip=2') {
                    return @{ Body = '{"value":[{"id":3,"name":"C"}],"count":3}'; ContentType = 'application/json' }
                }
                return @{ Body = '{"value":[{"id":1,"name":"A"},{"id":2,"name":"B"}],"nextLink":"/v1/pets?skip=2","count":3}'; ContentType = 'application/json' }
            }
            '^GET /v1/pets/\d+$' { return @{ Body = '{"id":7,"name":"Rex"}'; ContentType = 'application/json' } }
            '^POST /v1/pets$' { return @{ StatusCode = 201; Body = $Request.Body; ContentType = 'application/json' } }
            '^PUT /v1/pets/\d+/photo$' { return @{ Body = [byte[]](137, 80, 78, 71); ContentType = 'image/png' } }
            '^GET /v1/stores$' {
                if ($Request.RawUrl -match 'page=2') {
                    return @{ Body = '[{"id":"s3"}]'; ContentType = 'application/json' }
                }
                return @{ Body = '[{"id":"s1"},{"id":"s2"}]'; ContentType = 'application/json'; Headers = @{ Link = '</v1/stores?page=2>; rel="next"' } }
            }
            '^GET /v2/pets$' { return @{ Body = '[{"id":1,"name":"A"}]'; ContentType = 'application/json' } }
            '^POST /v2/pets$' { return @{ StatusCode = 201; Body = $Request.Body; ContentType = 'application/json' } }
            '^POST /v2/pets/\d+$' { return @{ StatusCode = 200 } }
            '^POST /v2/pets/\d+/image$' { return @{ StatusCode = 200 } }
            '^GET /v2/pets/\d+/image$' { return @{ Body = [byte[]](1, 2, 3); ContentType = 'image/png' } }
            '^POST /v2/token$' { return @{ Body = '{"access_token":"t2","expires_in":600}'; ContentType = 'application/json' } }
            '^GET /v31/items$' {
                if ($Request.RawUrl -match 'next=1') {
                    return @{ Body = '{"items":[{"id":"3"}]}'; ContentType = 'application/json' }
                }
                return @{ Body = '{"items":[{"id":"1"},{"id":"2"}],"@odata.nextLink":"{{BaseUri}}/v31/items?next=1"}'; ContentType = 'application/json' }
            }
            '^POST /v31/items$' { return @{ StatusCode = 201 } }
            '^DELETE ' { return @{ StatusCode = 204 } }
        }
        return @{ StatusCode = 404; Body = 'not scripted'; ContentType = 'text/plain' }
    }
    $script:outputRoot = Join-Path -Path $TestDrive -ChildPath 'generated'
    $script:secret = {
        param([string]$Text)
        ConvertTo-SecureString -String $Text -AsPlainText -Force
    }
}

AfterAll {
    $script:server.Stop()
    foreach ($name in @('PetStore', 'Legacy', 'Modern', 'tcs.openapi')) {
        Remove-Module -Name $name -Force -ErrorAction SilentlyContinue
    }
}

Describe 'End to end: OpenAPI 3.0 petstore fixture' {
    BeforeAll {
        $script:petstore = New-EndToEndModule -Fixture 'document-petstore-3.0.json' -ModuleName 'PetStore' -NounPrefix 'PetStore' -OutputPath $script:outputRoot
        Import-Module -Name $script:petstore.ManifestPath -Force
        Set-PetStoreContext -BaseUri "$($script:server.BaseUri)/v1" -ApiKey (& $script:secret 'pet-key') -Credential (New-Object System.Management.Automation.PSCredential -ArgumentList 'admin', (& $script:secret 'pw'))
    }

    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'defaults -BaseUri of Set-PetStoreContext to the first absolute server' {
        (Get-Command -Name Set-PetStoreContext).ScriptBlock.Ast.Body.ParamBlock.Parameters.Where({ $_.Name.VariablePath.UserPath -eq 'BaseUri' })[0].DefaultValue.Value | Should -Be 'https://eu.petstore.example.com/v1'
    }

    It 'lists pets with the api key of the default security and types the page items' {
        $pets = @(Get-PetStorePet -Limit 2 -Status 'available')
        $pets.name | Should -Be @('A', 'B')
        $pets | ForEach-Object -Process { $_.PSObject.TypeNames[0] | Should -Be 'PetStore.Pet' }
        $request = $script:server.Requests[0]
        $request.Headers['X-API-Key'] | Should -Be 'pet-key'
        Get-EndToEndQueryPair -Request $request | Should -Contain 'limit=2'
        Get-EndToEndQueryPair -Request $request | Should -Contain 'status=available'
    }

    It 'follows a relative nextLink with -All' {
        @(Get-PetStorePet -All).id | Should -Be @(1, 2, 3)
        @($script:server.Requests.ToArray().RawUrl) | Should -Be @('/v1/pets', '/v1/pets?skip=2')
    }

    It 'gets one pet by an int64 path parameter, asking for JSON first' {
        $pet = Get-PetStorePetById -PetId 7
        $pet.name | Should -Be 'Rex'
        $pet.PSObject.TypeNames[0] | Should -Be 'PetStore.Pet'
        $script:server.Requests[0].RawUrl | Should -Be '/v1/pets/7'
        $script:server.Requests[0].Headers['Accept'] | Should -Match '^application/json'
    }

    It 'creates a pet without credentials (security: []), with a nested schema property' {
        $pet = New-PetStorePet -Name 'Rex' -Category @{ id = 1; name = 'dogs' } -Confirm:$false
        $request = $script:server.Requests[0]
        $request.Headers['X-API-Key'] | Should -BeNullOrEmpty
        $body = $request.Body | ConvertFrom-Json
        $body.name | Should -Be 'Rex'
        $body.category.name | Should -Be 'dogs'
        $pet.PSObject.TypeNames[0] | Should -Be 'PetStore.Pet'
    }

    It 'validates parameters from the schema before sending' {
        { New-PetStorePet -Name 'R3x!' -Confirm:$false } | Should -Throw
        { Get-PetStorePet -Limit 101 } | Should -Throw
        $script:server.Requests.Count | Should -Be 0
    }

    It 'deletes with basic auth (the second security requirement) and warns that the operation is deprecated' {
        $warnings = $null
        Remove-PetStorePetRecord -PetId 7 -Confirm:$false -WarningVariable warnings -WarningAction SilentlyContinue
        $request = $script:server.Requests[0]
        $request.Method | Should -Be 'DELETE'
        $request.Headers['Authorization'] | Should -BeLike 'Basic *'
        @($warnings).Count | Should -Be 1
        $warnings[0].Message | Should -Match 'deprecated'
    }

    It 'uploads a binary body and returns the binary response (x-ps-name command)' {
        $photo = Join-Path -Path $TestDrive -ChildPath 'photo.bin'
        [System.IO.File]::WriteAllBytes($photo, [byte[]](5, 6))
        $bytes = Set-PetPhoto -PetId 3 -Body (Get-Item -LiteralPath $photo) -Confirm:$false
        $bytes | Should -Be @(137, 80, 78, 71)
        $script:server.Requests[0].BodyBytes | Should -Be @(5, 6)
        $script:server.Requests[0].ContentType | Should -Be 'application/octet-stream'
    }

    It 'follows a relative Link header with -All (operation without operationId)' {
        @(Get-PetStoreStore -All).id | Should -Be @('s1', 's2', 's3')
        $script:server.Requests.Count | Should -Be 2
    }
}

Describe 'End to end: Swagger 2.0 fixture' {
    BeforeAll {
        $script:legacy = New-EndToEndModule -Fixture 'document-swagger-2.0.json' -ModuleName 'Legacy' -NounPrefix 'Lg' -OutputPath $script:outputRoot
        Import-Module -Name $script:legacy.ManifestPath -Force
        Set-LgContext -BaseUri "$($script:server.BaseUri)/v2" -ApiKey (& $script:secret 'legacy-key') -ClientId 'c' -ClientSecret (& $script:secret 's') -TokenUri "$($script:server.BaseUri)/v2/token"
    }

    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'defaults -BaseUri to https://host/basePath' {
        (Get-Command -Name Set-LgContext).ScriptBlock.Ast.Body.ParamBlock.Parameters.Where({ $_.Name.VariablePath.UserPath -eq 'BaseUri' })[0].DefaultValue.Value | Should -Be 'https://petstore.example.com/v2'
    }

    It 'maps collectionFormat csv, multi and pipes' {
        $pets = @(Find-Pet -Tags 'a', 'b' -Status 'available', 'sold' -Ids 1, 2)
        $pets[0].PSObject.TypeNames[0] | Should -Be 'Legacy.Pet'
        $pairs = Get-EndToEndQueryPair -Request $script:server.Requests[0]
        $pairs | Should -Contain 'tags=a,b'
        $pairs | Should -Contain 'status=available'
        $pairs | Should -Contain 'status=sold'
        $pairs | Should -Contain 'ids=1%7C2'
        $script:server.Requests[0].Headers['api_key'] | Should -Be 'legacy-key'
    }

    It 'sends a body parameter as JSON with an OAuth2 (application flow) token' {
        New-LgPet -Name 'Rex' -Confirm:$false | Out-Null
        @(Get-EndToEndRequest -Server $script:server -Method POST -Path '/v2/token').Count | Should -Be 1
        $request = @(Get-EndToEndRequest -Server $script:server -Method POST -Path '/v2/pets')[0]
        $request.Headers['Authorization'] | Should -Be 'Bearer t2'
        ($request.Body | ConvertFrom-Json).name | Should -Be 'Rex'
    }

    It 'sends formData as a form body' {
        Update-LgPetWithForm -PetId 4 -Body @{ name = 'Max'; status = 'sold' } -Confirm:$false
        $request = $script:server.Requests[0]
        $request.ContentType | Should -Be 'application/x-www-form-urlencoded'
        @($request.Body.Split('&') | Sort-Object) | Should -Be @('name=Max', 'status=sold')
    }

    It 'sends a file formData parameter as multipart' {
        $file = Join-Path -Path $TestDrive -ChildPath 'image.png'
        [System.IO.File]::WriteAllBytes($file, [byte[]](65, 66))
        New-LgUploadImage -PetId 4 -Body @{ additionalMetadata = 'meta'; file = (Get-Item -LiteralPath $file) } -Confirm:$false
        $request = $script:server.Requests[0]
        $request.ContentType | Should -Match '^multipart/form-data'
        $request.Body | Should -Match 'filename="?image\.png"?'
        $request.Body | Should -Match 'meta'
    }

    It 'downloads a file response with -OutFile' {
        $target = Join-Path -Path $TestDrive -ChildPath 'download.png'
        $file = Get-LgImage -PetId 4 -OutFile $target
        $file.Length | Should -Be 3
        $script:server.Requests[0].Headers['Accept'] | Should -Be 'image/png'
    }

    It 'sends a DELETE without credentials (security: []) using the operation-level path parameter type' {
        Remove-LgPet -PetId 'abc' -Confirm:$false
        $request = $script:server.Requests[0]
        $request.RawUrl | Should -Be '/v2/pets/abc'
        $request.Headers['api_key'] | Should -BeNullOrEmpty
    }
}

Describe 'End to end: OpenAPI 3.1 fixture without a noun prefix' {
    BeforeAll {
        $script:modern = New-EndToEndModule -Fixture 'document-openapi-3.1.json' -ModuleName 'Modern' -OutputPath $script:outputRoot
        Import-Module -Name $script:modern.ManifestPath -Force
        Set-ModernContext -BaseUri "$($script:server.BaseUri)/v31"
    }

    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'does not shadow Get-Item or New-Item (OA042)' {
        @($script:modern.Functions.Name) | Should -Contain 'Get-ModernItem'
        @($script:modern.Functions.Name) | Should -Contain 'New-ModernItem'
        @($script:modern.Functions.Name) | Should -Not -Contain 'Get-Item'
        @($script:modern.Findings | Where-Object -FilterScript { $_.Code -eq 'OA042' }).Count | Should -Be 2
        (Get-Command -Name Get-Item).Source | Should -Be 'Microsoft.PowerShell.Management'
    }

    It 'follows an x-ms-pageable @odata.nextLink with -All' {
        $items = @(Get-ModernItem -All)
        $items.id | Should -Be @('1', '2', '3')
        $items[0].PSObject.TypeNames[0] | Should -Be 'Modern.Item'
    }

    It 'sends a JSON body with a nullable property as null' {
        New-ModernItem -Note $null -Confirm:$false
        $body = $script:server.Requests[0].Body | ConvertFrom-Json
        $body.PSObject.Properties.Name | Should -Contain 'note'
        $body.note | Should -BeNullOrEmpty
    }
}
