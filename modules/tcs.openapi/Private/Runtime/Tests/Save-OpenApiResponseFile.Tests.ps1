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

Describe 'Save-OpenApiResponseFile' {
    It 'streams the response content to a file and disposes the message' {
        InModuleScope -ModuleName tcs.openapi {
            $bytes = [byte[]](0..255)
            $message = New-Object System.Net.Http.HttpResponseMessage -ArgumentList ([System.Net.HttpStatusCode]::OK)
            $message.Content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $bytes)
            $response = [pscustomobject]@{ Message = $message; Body = $null }
            $path = Join-Path -Path $TestDrive -ChildPath 'out.bin'
            $file = Save-OpenApiResponseFile -Response $response -Path $path
            $file | Should -BeOfType ([System.IO.FileInfo])
            [System.IO.File]::ReadAllBytes($path) | Should -Be $bytes
            $response.Message | Should -BeNullOrEmpty
        }
    }

    It 'writes an already read body' {
        InModuleScope -ModuleName tcs.openapi {
            $path = Join-Path -Path $TestDrive -ChildPath 'body.bin'
            $null = Save-OpenApiResponseFile -Response ([pscustomobject]@{ Message = $null; Body = [byte[]](5, 6) }) -Path $path
            [System.IO.File]::ReadAllBytes($path) | Should -Be ([byte[]](5, 6))
        }
    }

    It 'throws when the folder does not exist' {
        InModuleScope -ModuleName tcs.openapi {
            $path = Join-Path -Path (Join-Path -Path $TestDrive -ChildPath 'missing') -ChildPath 'x.bin'
            { Save-OpenApiResponseFile -Response ([pscustomobject]@{ Message = $null; Body = [byte[]](1) }) -Path $path } | Should -Throw -ExceptionType ([System.IO.DirectoryNotFoundException])
        }
    }
}
