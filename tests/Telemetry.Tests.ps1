BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $ModuleRoot = Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.openapi'
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
    $Fixtures = Join-Path -Path $PSScriptRoot -ChildPath 'Fixtures'
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Command telemetry' {
    BeforeEach {
        Mock -ModuleName tcs.core Invoke-TelemetryCollection { }
    }

    It 'records every exported command with Start-TcsTelemetry and Complete-TcsTelemetry, never Invoke-TcsCommand' {
        foreach ($file in Get-ChildItem -Path (Join-Path -Path $ModuleRoot -ChildPath 'Public') -Filter '*.ps1') {
            $text = Get-Content -LiteralPath $file.FullName -Raw
            $text | Should -Not -Match 'Invoke-TcsCommand' -Because $file.Name
            if ($file.BaseName -ne 'Invoke-OpenApiRequest') {
                $text | Should -Match 'Start-TcsTelemetry' -Because $file.Name
                $text | Should -Match 'Complete-TcsTelemetry' -Because $file.Name
            }
        }
    }

    It 'writes "<Command>" not-found errors from the command itself and records a failed run' -TestCases @(
        @{ Command = 'Get-OpenApiContext' }
        @{ Command = 'Remove-OpenApiContext' }
    ) {
        param($Command)
        $errors = $null
        $output = & $Command -Service 'NoSuchService' -ErrorAction SilentlyContinue -ErrorVariable errors
        $output | Should -BeNullOrEmpty
        @($errors).Count | Should -Be 1
        $errors[0].FullyQualifiedErrorId | Should -Be "OpenApi.ContextNotFound,$Command"
        Should -Invoke Invoke-TelemetryCollection -ModuleName tcs.core -Times 1 -Exactly -ParameterFilter {
            $CommandName -eq $Command -and $Stage -eq 'End' -and $Failed -eq $true
        }
    }

    It 'records a successful run for a context that exists' {
        Set-OpenApiContext -Service 'Telemetry' -BaseUri 'https://telemetry.example'
        $null = Get-OpenApiContext -Service 'Telemetry'
        Should -Invoke Invoke-TelemetryCollection -ModuleName tcs.core -Times 1 -Exactly -ParameterFilter {
            $CommandName -eq 'Get-OpenApiContext' -and $Stage -eq 'End' -and -not $Failed
        }
    }

    It 'records one End event for <Command> when Select-Object -First stops the pipeline' -TestCases @(
        @{ Command = 'Import-OpenApiDocument' }
        @{ Command = 'Test-OpenApiDocument' }
    ) {
        param($Command)
        $paths = @('document-petstore-3.0.json', 'document-swagger-2.0.json') | ForEach-Object { Join-Path -Path $Fixtures -ChildPath $_ }
        $null = Get-Item -Path $paths | & $Command -InformationAction SilentlyContinue | Select-Object -First 1
        Should -Invoke Invoke-TelemetryCollection -ModuleName tcs.core -Times 1 -Exactly -ParameterFilter {
            $CommandName -eq $Command -and $Stage -eq 'End'
        }
    }

    It 'records an unsupported version from Import-OpenApiDocument as a failed run' {
        { Import-OpenApiDocument -InputObject '{"openapi":"3.2.0","paths":{}}' -ErrorAction Stop } | Should -Throw -ErrorId 'OpenApi.UnsupportedVersion*'
        Should -Invoke Invoke-TelemetryCollection -ModuleName tcs.core -Times 1 -Exactly -ParameterFilter {
            $CommandName -eq 'Import-OpenApiDocument' -and $Stage -eq 'End' -and $Failed -eq $true
        }
    }
}
