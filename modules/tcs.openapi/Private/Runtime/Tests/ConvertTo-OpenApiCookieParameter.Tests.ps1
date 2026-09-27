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

Describe 'ConvertTo-OpenApiCookieParameter' {
    It 'uses the form style: <Kind> explode=<Explode> -> <Expected>' -ForEach @(
        @{ Kind = 'string'; Explode = $true; Expected = 'color=blue' }
        @{ Kind = 'array'; Explode = $false; Expected = 'color=blue,black,brown' }
        @{ Kind = 'array'; Explode = $true; Expected = 'color=blue; color=black; color=brown' }
        @{ Kind = 'object'; Explode = $false; Expected = 'color=R,100,G,200,B,150' }
        @{ Kind = 'object'; Explode = $true; Expected = 'R=100; G=200; B=150' }
    ) {
        $values = @{ string = 'blue'; array = @('blue', 'black', 'brown'); object = [ordered]@{ R = 100; G = 200; B = 150 } }
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Value = $values[$Kind]; Explode = $Explode; Expected = $Expected } {
            (ConvertTo-OpenApiCookieParameter -Name 'color' -Value $Value -Explode:$Explode) -join '; ' | Should -BeExactly $Expected
        }
    }

    It 'percent-encodes characters that are not allowed in cookie values' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertTo-OpenApiCookieParameter -Name 'c' -Value 'a b;c') -join '; ' | Should -BeExactly 'c=a%20b%3Bc'
        }
    }
}
