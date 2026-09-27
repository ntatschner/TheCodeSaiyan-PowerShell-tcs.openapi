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

Describe 'Get-OpenApiRedactedText' {
    It 'redacts JSON properties named like secrets' {
        InModuleScope -ModuleName tcs.openapi {
            $text = '{"user":"u","password":"p","apiKey":"k","api_key":12,"clientSecret":"c","client_secret":"c2","access_token":"t","nested":{"refreshToken":"r","ok":true},"secretFlag":false,"n":null}'
            $result = Get-OpenApiRedactedText -Text $text
            $result | Should -BeExactly '{"user":"u","password":"********","apiKey":"********","api_key":"********","clientSecret":"********","client_secret":"********","access_token":"********","nested":{"refreshToken":"********","ok":true},"secretFlag":"********","n":null}'
        }
    }

    It 'handles escaped quotes inside secret values' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiRedactedText -Text '{"password":"a\"b","x":1}' | Should -BeExactly '{"password":"********","x":1}'
        }
    }

    It 'redacts form-urlencoded pairs' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiRedactedText -Text 'grant_type=client_credentials&client_id=app&client_secret=s%20x&scope=a' | Should -BeExactly 'grant_type=client_credentials&client_id=app&client_secret=********&scope=a'
            Get-OpenApiRedactedText -Text 'password=x' | Should -BeExactly 'password=********'
        }
    }

    It 'leaves other text alone' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiRedactedText -Text 'hello' | Should -BeExactly 'hello'
            Get-OpenApiRedactedText -Text '' | Should -BeExactly ''
        }
    }
}
