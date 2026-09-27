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

Describe 'New-OpenApiRequestUri' {
    It 'joins base URI and path and expands path parameters with their style' {
        InModuleScope -ModuleName tcs.openapi {
            $parameters = @(@{ Name = 'id'; In = 'path' }, @{ Name = 'c'; In = 'path'; Style = 'matrix'; Explode = $true })
            New-OpenApiRequestUri -BaseUri 'https://a/v1/' -Path '/pets/{id}/x{c}' -Parameter $parameters -PathParameters @{ id = 'a/b'; c = @(1, 2) } | Should -Be 'https://a/v1/pets/a%2Fb/x;c=1;c=2'
            New-OpenApiRequestUri -BaseUri 'https://a' -Path 'pets' | Should -Be 'https://a/pets'
        }
    }

    It 'adds query parameters with their style, defaulting to form/explode' {
        InModuleScope -ModuleName tcs.openapi {
            $parameters = @(@{ Name = 'ids'; In = 'query'; Style = 'pipeDelimited'; Explode = $false })
            $query = [ordered]@{ ids = @(1, 2); tags = @('a', 'b') }
            New-OpenApiRequestUri -BaseUri 'https://a' -Path '/p' -Parameter $parameters -QueryParameters $query | Should -Be 'https://a/p?ids=1|2&tags=a&tags=b'
        }
    }

    It 'throws ArgumentException for a missing path parameter' {
        InModuleScope -ModuleName tcs.openapi {
            { New-OpenApiRequestUri -BaseUri 'https://a' -Path '/p/{id}' -PathParameters @{} } | Should -Throw -ExceptionType ([System.ArgumentException]) -ExpectedMessage "*'id'*"
        }
    }
}
