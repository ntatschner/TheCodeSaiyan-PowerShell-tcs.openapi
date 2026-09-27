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

Describe 'Build-OpenApiHttpContent' {
    It 'serialises JSON with charset utf-8' {
        InModuleScope -ModuleName tcs.openapi {
            $content = Build-OpenApiHttpContent -Body ([ordered]@{ a = $null; b = @(1) }) -ContentType 'application/json'
            $content.Headers.ContentType.ToString() | Should -Be 'application/json; charset=utf-8'
            $content.ReadAsStringAsync().GetAwaiter().GetResult() | Should -Be '{"a":null,"b":[1]}'
        }
    }

    It 'keeps content type parameters and a given charset' {
        InModuleScope -ModuleName tcs.openapi {
            $content = Build-OpenApiHttpContent -Body @{ a = 1 } -ContentType 'application/merge-patch+json; charset=utf-16'
            $content.Headers.ContentType.MediaType | Should -Be 'application/merge-patch+json'
            $content.Headers.ContentType.CharSet | Should -Be 'utf-16'
        }
    }

    It 'sends explicit null as JSON null' {
        InModuleScope -ModuleName tcs.openapi {
            (Build-OpenApiHttpContent -Body $null -ContentType 'application/json').ReadAsStringAsync().GetAwaiter().GetResult() | Should -Be 'null'
        }
    }

    It 'encodes forms, text and binary bodies' {
        InModuleScope -ModuleName tcs.openapi {
            $form = Build-OpenApiHttpContent -Body ([ordered]@{ a = 'x y' }) -ContentType 'application/x-www-form-urlencoded'
            $form.ReadAsStringAsync().GetAwaiter().GetResult() | Should -Be 'a=x%20y'
            $text = Build-OpenApiHttpContent -Body '<a/>' -ContentType 'application/xml'
            $text.Headers.ContentType.ToString() | Should -Be 'application/xml; charset=utf-8'
            $binary = Build-OpenApiHttpContent -Body ([byte[]](9, 8)) -ContentType 'application/octet-stream'
            $binary.Headers.ContentType.ToString() | Should -Be 'application/octet-stream'
            $binary.ReadAsByteArrayAsync().GetAwaiter().GetResult() | Should -Be ([byte[]](9, 8))
        }
    }

    It 'returns multipart content as one object' {
        InModuleScope -ModuleName tcs.openapi {
            $content = Build-OpenApiHttpContent -Body @{ a = 'b' } -ContentType 'multipart/form-data'
            # The content is a collection of parts; it must come back as the multipart object itself
            , $content | Should -BeOfType ([System.Net.Http.MultipartFormDataContent])
        }
    }
}
