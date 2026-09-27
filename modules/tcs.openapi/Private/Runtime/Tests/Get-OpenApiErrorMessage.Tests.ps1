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

Describe 'Get-OpenApiErrorMessage' {
    It 'uses problem+json title and detail' {
        InModuleScope -ModuleName tcs.openapi {
            $message = Get-OpenApiErrorMessage -StatusCode 400 -ReasonPhrase 'Bad Request' -Body ([pscustomobject]@{ title = 'Invalid'; detail = 'Name is required.' }) -Method 'POST' -Uri 'https://a/x'
            $message | Should -BeExactly 'The request POST https://a/x failed with status 400 (Bad Request). Invalid: Name is required.'
            Get-OpenApiErrorMessage -StatusCode 400 -Body ([pscustomobject]@{ title = 'Only title' }) | Should -Match 'Only title$'
        }
    }

    It 'reads common error shapes' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiErrorMessage -StatusCode 400 -Body ([pscustomobject]@{ message = 'm1' }) | Should -Match 'm1$'
            Get-OpenApiErrorMessage -StatusCode 400 -Body ([pscustomobject]@{ error = [pscustomobject]@{ message = 'm2' } }) | Should -Match 'm2$'
            Get-OpenApiErrorMessage -StatusCode 400 -Body ([pscustomobject]@{ error = 'bad'; error_description = 'why' }) | Should -Match 'bad: why$'
        }
    }

    It 'uses a short text body but not HTML pages' {
        InModuleScope -ModuleName tcs.openapi {
            Get-OpenApiErrorMessage -StatusCode 502 -ReasonPhrase 'Bad Gateway' -Body 'upstream down' | Should -Match 'upstream down$'
            Get-OpenApiErrorMessage -StatusCode 502 -ReasonPhrase 'Bad Gateway' -Body '<html><body>x</body></html>' | Should -Match '\(Bad Gateway\)\.$'
        }
    }
}
