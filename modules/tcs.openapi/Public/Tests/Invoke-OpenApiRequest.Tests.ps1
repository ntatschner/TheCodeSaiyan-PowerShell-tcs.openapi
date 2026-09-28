BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path $PSScriptRoot -Parent | Split-Path -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/TestHttpServer.ps1')
    $script:server = Start-TestHttpServer -Handler { param($Request) @{ Body = @{ method = $Request.Method; path = $Request.Path } } }
    Set-OpenApiContext -Service 'Direct' -BaseUri $script:server.BaseUri
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest' {
    BeforeEach {
        $script:server.Requests.Clear()
    }

    It 'accepts the operation metadata as a hashtable or a PSCustomObject' {
        $hashtable = @{ OperationId = 'a'; Method = 'get'; Path = '/h/{id}'; Parameters = @(@{ Name = 'id'; In = 'path' }); Security = @() }
        (Invoke-OpenApiRequest -Service 'Direct' -Operation $hashtable -PathParameters @{ id = 1 }).path | Should -Be '/h/1'
        $json = '{"OperationId":"b","Method":"DELETE","Path":"/o/{id}","Parameters":[{"Name":"id","In":"path","Style":null,"Explode":null,"AllowReserved":false}],"Security":[],"SecuritySchemes":{},"Paging":null,"ResponseTypeName":"Direct.Thing","PSTypeName":"Tcs.OpenApi.OperationMetadata"}'
        $object = $json | ConvertFrom-Json
        $result = Invoke-OpenApiRequest -Service 'Direct' -Operation $object -PathParameters @{ id = 'x' }
        $result.method | Should -Be 'DELETE'
        $result.path | Should -Be '/o/x'
        $result.PSObject.TypeNames[0] | Should -Be 'Direct.Thing'
    }

    It 'defaults to GET and sends a User-Agent and Accept header' {
        $null = Invoke-OpenApiRequest -Service 'Direct' -Operation @{ Path = '/x' }
        $script:server.Requests[0].Method | Should -Be 'GET'
        $script:server.Requests[0].Headers['User-Agent'] | Should -Match '^tcs\.openapi/'
        $script:server.Requests[0].Headers['Accept'] | Should -Match 'application/json'
    }

    It 'sends the operation response content types as Accept' {
        $null = Invoke-OpenApiRequest -Service 'Direct' -Operation @{ Path = '/x'; ResponseContentTypes = @('application/xml', 'text/csv') }
        $script:server.Requests[0].Headers['Accept'] | Should -Be 'application/xml, text/csv'
    }

    It 'reads a stream body once and never hands the caller''s stream to the HTTP layer' {
        # On .NET Framework HttpClient disposes the request content, so a stream passed through would be closed
        Mock -ModuleName tcs.openapi -CommandName New-OpenApiHttpContent -MockWith {
            New-Object System.Net.Http.ByteArrayContent -ArgumentList (, [byte[]]$Body)
        }
        $stream = New-Object System.IO.MemoryStream -ArgumentList (, [byte[]](1, 2, 3))
        $stream.Position = 2
        $null = Invoke-OpenApiRequest -Service 'Direct' -Operation @{ Path = '/x'; Method = 'PUT'; RequestContentTypes = @('application/octet-stream') } -Body $stream
        Should -Invoke -ModuleName tcs.openapi -CommandName New-OpenApiHttpContent -Times 1 -Exactly -ParameterFilter { $Body -is [byte[]] }
        $script:server.Requests[0].BodyBytes | Should -Be ([byte[]](1, 2, 3))
        $stream.CanRead | Should -BeTrue
        $stream.Position | Should -Be 2
        $stream.Dispose()
    }

    It 'takes the caller''s preferences and sends a read under $WhatIfPreference' {
        # A generated Get- command has no -WhatIf, so a session-wide $WhatIfPreference must not stop the engine
        # from copying the caller's preferences (Set-Variable honours -WhatIf) or from sending the request.
        # $WhatIfPreference reaches the module through the global scope, so it is set there
        function Invoke-TestRead {
            [CmdletBinding()]
            param()
            Invoke-OpenApiRequest -Service 'Direct' -Operation @{ Path = '/read' } -Cmdlet $PSCmdlet
        }
        $saved = $global:WhatIfPreference
        try {
            $global:WhatIfPreference = $true
            $output = @(Invoke-TestRead -Verbose 4>&1)
        }
        finally {
            $global:WhatIfPreference = $saved
        }
        $script:server.Requests.Count | Should -Be 1
        @($output | Where-Object -FilterScript { $_ -is [System.Management.Automation.VerboseRecord] }).Count | Should -BeGreaterThan 0
        ($output | Where-Object -FilterScript { $_ -isnot [System.Management.Automation.VerboseRecord] }).path | Should -Be '/read'
    }

    It 'writes an error when no service name is known' {
        { Invoke-OpenApiRequest -Operation @{ Path = '/x' } -ErrorAction Stop } | Should -Throw -ErrorId 'OpenApi.MissingService*'
    }

    It 'has comment-based help for every parameter' {
        $help = Get-Help -Name Invoke-OpenApiRequest -Full
        $help.Synopsis | Should -Not -BeNullOrEmpty
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
        foreach ($name in 'Service', 'Operation', 'PathParameters', 'QueryParameters', 'HeaderParameters', 'CookieParameters', 'Body', 'ContentType', 'OutFile', 'All', 'Raw', 'Cmdlet') {
            ($help.Parameters.Parameter | Where-Object -FilterScript { $_.Name -eq $name }).Description | Should -Not -BeNullOrEmpty
        }
    }
}
