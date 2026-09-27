BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')

    $script:server = Start-TestHttpServer -Routes @{
        'GET /pets/7'       = @{ Body = '{"id":7,"name":"Rex"}'; ContentType = 'application/json' }
        'GET /pets'         = @{ Body = '{"value":[{"id":1}],"nextLink":"{{BaseUri}}/pets/more"}'; ContentType = 'application/json' }
        'GET /pets/more'    = @{ Body = '{"value":[{"id":2}]}'; ContentType = 'application/json' }
        'POST /oauth/token' = @{ Body = '{"access_token":"fixture-token","expires_in":600}'; ContentType = 'application/json' }
        'POST /pets'        = @{ StatusCode = 201; Body = '{"id":9,"name":"New"}'; ContentType = 'application/json' }
        'GET /pets/7/photo' = @{ Body = [byte[]](137, 80, 78, 71); ContentType = 'image/png' }
    }

    # What a generated module does: load OpenApi/operations.json into a hashtable keyed by operationId
    $json = [System.IO.File]::ReadAllText((Join-Path -Path $PSScriptRoot -ChildPath 'Fixtures/runtime-operations.json')).Replace('{{BaseUri}}', $script:server.BaseUri)
    $script:operations = @{}
    foreach ($property in ($json | ConvertFrom-Json).PSObject.Properties) {
        $script:operations[$property.Name] = $property.Value
    }
    $secret = (New-Object -TypeName System.Net.NetworkCredential -ArgumentList '', 'fixture-key').SecurePassword
    Set-OpenApiContext -Service 'Fixture' -BaseUri $script:server.BaseUri -ApiKey $secret -ClientId 'app' -ClientSecret $secret
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest with operation metadata loaded from operations.json' {
    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'gets one object, using the scheme of a null Security (document default) and styled parameters' {
        $pet = Invoke-OpenApiRequest -Service 'Fixture' -Operation $script:operations['getPetById'] -PathParameters @{ petId = 7 } -QueryParameters @{ fields = @('id', 'name') } -HeaderParameters @{ 'X-Request-Id' = 'r1' }
        $pet.name | Should -Be 'Rex'
        $pet.PSObject.TypeNames[0] | Should -Be 'Fixture.Pet'
        $request = $script:server.Requests[0]
        $request.RawUrl | Should -Be '/pets/7?fields=id,name'
        $request.Headers['X-API-Key'] | Should -Be 'fixture-key'
        $request.Headers['X-Request-Id'] | Should -Be 'r1'
        $request.Headers['Accept'] | Should -Be 'application/json'
    }

    It 'pages with -All' {
        @(Invoke-OpenApiRequest -Service 'Fixture' -Operation $script:operations['listPets'] -All).id | Should -Be @(1, 2)
    }

    It 'creates with an OAuth2 token from the flow in the metadata' {
        $pet = Invoke-OpenApiRequest -Service 'Fixture' -Operation $script:operations['createPet'] -Body @{ name = 'New' }
        $pet.id | Should -Be 9
        $script:server.Requests[0].Path | Should -Be '/oauth/token'
        $script:server.Requests[0].Body | Should -Match 'scope=write%3Apets'
        $script:server.Requests[1].Headers['Authorization'] | Should -Be 'Bearer fixture-token'
        $script:server.Requests[1].ContentType | Should -Be 'application/json; charset=utf-8'
    }

    It 'downloads a binary response and warns that the operation is deprecated' {
        $path = Join-Path -Path $TestDrive -ChildPath 'photo.png'
        $warnings = $null
        $file = Invoke-OpenApiRequest -Service 'Fixture' -Operation $script:operations['downloadPhoto'] -PathParameters @{ petId = 7 } -OutFile $path -WarningVariable warnings -WarningAction SilentlyContinue
        $file.Length | Should -Be 4
        @($warnings).Count | Should -Be 1
    }
}
