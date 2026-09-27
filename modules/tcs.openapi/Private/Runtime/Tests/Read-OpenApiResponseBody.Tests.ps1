BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Read-OpenApiResponseBody' {
    It 'reads the body once, disposes the message and returns bytes' {
        InModuleScope -ModuleName tcs.openapi {
            $message = New-Object System.Net.Http.HttpResponseMessage -ArgumentList ([System.Net.HttpStatusCode]::OK)
            $message.Content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, [byte[]](1, 2))
            $response = [pscustomobject]@{ Message = $message; Body = $null }
            $bytes = Read-OpenApiResponseBody -Response $response
            , $bytes | Should -BeOfType ([byte[]])
            $bytes | Should -Be ([byte[]](1, 2))
            $response.Message | Should -BeNullOrEmpty
            $again = Read-OpenApiResponseBody -Response $response
            $again | Should -Be ([byte[]](1, 2))
        }
    }

    It 'returns an empty array when there is no content' {
        InModuleScope -ModuleName tcs.openapi {
            $bytes = Read-OpenApiResponseBody -Response ([pscustomobject]@{ Message = $null; Body = $null })
            , $bytes | Should -BeOfType ([byte[]])
            $bytes.Length | Should -Be 0
        }
    }
}
