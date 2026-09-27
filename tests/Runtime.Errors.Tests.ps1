BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Helpers/TestHttpServer.ps1')
    $script:server = Start-TestHttpServer -Handler {
        param($Request)
        switch -Regex ($Request.Path) {
            '/pets/404$' {
                return @{ StatusCode = 404; ContentType = 'application/problem+json'; Body = '{"type":"about:blank","title":"Pet not found","status":404,"detail":"No pet with id 404.","password":"hunter2"}' }
            }
            '/pets/409$' {
                return @{ StatusCode = 409; ContentType = 'text/plain'; Body = 'Already exists' }
            }
            '/slow$' {
                return @{ DelayMilliseconds = 2500; Body = @{ late = $true } }
            }
            '/pets/(\d+)$' {
                return @{ Body = @{ id = [int]$Matches[1] } }
            }
        }
        return @{ StatusCode = 500 }
    }
    Set-OpenApiContext -Service 'Err' -BaseUri $script:server.BaseUri -MaxRetries 0

    $script:getPet = @{ OperationId = 'getPet'; Method = 'GET'; Path = '/pets/{petId}'; Security = @(); ResponseTypeName = 'Err.Pet' }

    # A wrapper like the ones New-OpenApiModule generates: errors go through its $PSCmdlet
    function Get-TestPet {
        [CmdletBinding()]
        param([Parameter(ValueFromPipeline)][int]$PetId)
        process {
            Invoke-OpenApiRequest -Service 'Err' -Operation $script:getPet -PathParameters @{ petId = $PetId } -Cmdlet $PSCmdlet
        }
    }

    function Get-OpenApiErrorFrom {
        param($Errors)
        return @($Errors | Where-Object -FilterScript { $_ -is [System.Management.Automation.ErrorRecord] -and $_.FullyQualifiedErrorId -like 'OpenApi.*' })
    }
}

AfterAll {
    $script:server.Stop()
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-OpenApiRequest errors (end to end)' {
    It 'writes an ErrorRecord with the status FQID, category, problem+json message and TargetObject' {
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Err' -Operation $script:getPet -PathParameters @{ petId = 404 } -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = (Get-OpenApiErrorFrom -Errors $errors)[0]
        $record.FullyQualifiedErrorId | Should -BeLike 'OpenApi.Err.404*'
        $record.CategoryInfo.Category | Should -Be 'ObjectNotFound'
        $record.Exception.Message | Should -Match 'Pet not found: No pet with id 404\.'
        $record.Exception.Message | Should -Match '404 \(Not Found\)'
        $record.TargetObject.Method | Should -Be 'GET'
        $record.TargetObject.Uri | Should -Be "$($script:server.BaseUri)/pets/404"
        $record.TargetObject.StatusCode | Should -Be 404
        $record.TargetObject.OperationId | Should -Be 'getPet'
        $record.TargetObject.Headers['Content-Type'] | Should -Be 'application/problem+json'
        $record.TargetObject.Body.title | Should -Be 'Pet not found'
    }

    It 'uses a short text body in the message' {
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Err' -Operation $script:getPet -PathParameters @{ petId = 409 } -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = (Get-OpenApiErrorFrom -Errors $errors)[0]
        $record.CategoryInfo.Category | Should -Be 'ResourceExists'
        $record.Exception.Message | Should -Match 'Already exists'
        $record.TargetObject.Body | Should -Be 'Already exists'
    }

    It '-ErrorAction SilentlyContinue suppresses the error' {
        $output = Invoke-OpenApiRequest -Service 'Err' -Operation $script:getPet -PathParameters @{ petId = 404 } -ErrorAction SilentlyContinue 2>&1
        $output | Should -BeNullOrEmpty
    }

    It 'writes a non-terminating error through -Cmdlet so the pipeline continues' {
        $errors = $null
        $results = @(1, 404, 2 | Get-TestPet -ErrorAction SilentlyContinue -ErrorVariable errors)
        $results.id | Should -Be @(1, 2)
        $results[0].PSObject.TypeNames[0] | Should -Be 'Err.Pet'
        $records = Get-OpenApiErrorFrom -Errors $errors
        $records.Count | Should -Be 1
        $records[0].FullyQualifiedErrorId | Should -Be 'OpenApi.Err.404,Get-TestPet'
    }

    It 'shows the error in the error stream of the caller' {
        $output = @(404 | Get-TestPet 2>&1)
        $output.Count | Should -Be 1
        $output[0] | Should -BeOfType ([System.Management.Automation.ErrorRecord])
        $output[0].FullyQualifiedErrorId | Should -BeLike 'OpenApi.Err.404*'
    }

    It 'becomes terminating with -ErrorAction Stop' {
        { 404 | Get-TestPet -ErrorAction Stop } | Should -Throw -ErrorId 'OpenApi.Err.404,Get-TestPet'
        { Invoke-OpenApiRequest -Service 'Err' -Operation $script:getPet -PathParameters @{ petId = 404 } -ErrorAction Stop } | Should -Throw '*Pet not found*'
    }

    It 'reports connection failures as OpenApi.<Service>.Connection' {
        $probe = New-Object System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback), 0
        $probe.Start()
        $port = ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
        $probe.Stop()
        Set-OpenApiContext -Service 'Down' -BaseUri "http://127.0.0.1:$port" -MaxRetries 0
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Down' -Operation $script:getPet -PathParameters @{ petId = 1 } -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = (Get-OpenApiErrorFrom -Errors $errors)[0]
        $record.FullyQualifiedErrorId | Should -BeLike 'OpenApi.Down.Connection*'
        $record.CategoryInfo.Category | Should -Be 'ConnectionError'
        $record.TargetObject.Uri | Should -Be "http://127.0.0.1:$port/pets/1"
    }

    It 'reports a timeout as a connection error with the OperationTimeout category' {
        Set-OpenApiContext -Service 'Slow' -BaseUri $script:server.BaseUri -TimeoutSec 1 -MaxRetries 0
        $errors = $null
        $operation = @{ OperationId = 'slow'; Method = 'GET'; Path = '/slow'; Security = @() }
        $null = Invoke-OpenApiRequest -Service 'Slow' -Operation $operation -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = (Get-OpenApiErrorFrom -Errors $errors)[0]
        $record.FullyQualifiedErrorId | Should -BeLike 'OpenApi.Slow.Connection*'
        $record.CategoryInfo.Category | Should -Be 'OperationTimeout'
        $record.Exception.Message | Should -Match 'timed out'
        Start-Sleep -Milliseconds 1600
    }

    It 'reports a missing context' {
        $errors = $null
        $null = Invoke-OpenApiRequest -Service 'Nowhere' -Operation $script:getPet -PathParameters @{ petId = 1 } -ErrorAction SilentlyContinue -ErrorVariable errors
        $record = (Get-OpenApiErrorFrom -Errors $errors)[0]
        $record.FullyQualifiedErrorId | Should -BeLike 'OpenApi.Nowhere.NoContext*'
        $record.Exception.Message | Should -Match 'Set-OpenApiContext'
    }

    It 'takes the service from the operation metadata when -Service is not given' {
        $operation = $script:getPet.Clone()
        $operation['Service'] = 'Err'
        (Invoke-OpenApiRequest -Operation $operation -PathParameters @{ petId = 7 }).id | Should -Be 7
    }
}
