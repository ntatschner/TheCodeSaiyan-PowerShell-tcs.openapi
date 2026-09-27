BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'New-OpenApiMultipartContent' {
    It 'creates one part per value with the right part types' {
        InModuleScope -ModuleName tcs.openapi {
            $path = Join-Path -Path $TestDrive -ChildPath 'f.txt'
            [System.IO.File]::WriteAllText($path, 'file')
            $body = [ordered]@{ text = 'v'; list = @(1, 2); file = Get-Item -LiteralPath $path; bytes = [byte[]](1); json = @{ a = 1 } }
            $content = New-OpenApiMultipartContent -Body $body
            $parts = @($content.GetEnumerator())
            $parts.Count | Should -Be 6
            $parts[0].Headers.ContentType.MediaType | Should -Be 'text/plain'
            $parts[3].Headers.ContentDisposition.FileName.Trim('"') | Should -Be 'f.txt'
            $parts[4].Headers.ContentDisposition.FileName.Trim('"') | Should -Be 'bytes'
            $parts[5].Headers.ContentType.MediaType | Should -Be 'application/json'
            $content.Dispose()
        }
    }

    It 'uses the boundary given in the content type' {
        InModuleScope -ModuleName tcs.openapi {
            $mediaType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('multipart/form-data; boundary=abc123')
            $content = New-OpenApiMultipartContent -Body @{ a = 'b' } -MediaType $mediaType
            $content.Headers.ContentType.ToString() | Should -Match 'boundary="?abc123"?'
        }
    }

    It 'rejects a body that is not a hashtable' {
        InModuleScope -ModuleName tcs.openapi {
            { New-OpenApiMultipartContent -Body 'text' } | Should -Throw -ExceptionType ([System.ArgumentException])
        }
    }
}
