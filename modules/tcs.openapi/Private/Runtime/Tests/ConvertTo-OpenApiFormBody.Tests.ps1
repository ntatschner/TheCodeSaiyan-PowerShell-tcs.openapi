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

Describe 'ConvertTo-OpenApiFormBody' {
    It 'encodes pairs, repeats arrays and writes booleans and dates like parameters' {
        InModuleScope -ModuleName tcs.openapi {
            $date = New-Object System.DateTime -ArgumentList 2024, 1, 1, 0, 0, 0, ([System.DateTimeKind]::Utc)
            ConvertTo-OpenApiFormBody -InputObject ([ordered]@{ 'a b' = 'c&d'; n = @(1, 2); t = $true; d = $date; e = $null }) | Should -BeExactly 'a%20b=c%26d&n=1&n=2&t=true&d=2024-01-01T00%3A00%3A00.0000000Z&e='
        }
    }

    It 'passes a string through and accepts a PSCustomObject' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiFormBody -InputObject 'raw=1' | Should -BeExactly 'raw=1'
            ConvertTo-OpenApiFormBody -InputObject ([pscustomobject]@{ a = 1 }) | Should -BeExactly 'a=1'
            ConvertTo-OpenApiFormBody -InputObject $null | Should -BeExactly ''
        }
    }
}
