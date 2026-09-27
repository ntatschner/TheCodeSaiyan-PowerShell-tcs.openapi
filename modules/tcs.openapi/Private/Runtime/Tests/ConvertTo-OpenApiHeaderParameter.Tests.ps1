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

Describe 'ConvertTo-OpenApiHeaderParameter' {
    It 'uses the simple style: <Kind> explode=<Explode> -> <Expected>' -ForEach @(
        @{ Kind = 'string'; Explode = $false; Expected = 'blue' }
        @{ Kind = 'array'; Explode = $false; Expected = 'blue,black,brown' }
        @{ Kind = 'array'; Explode = $true; Expected = 'blue,black,brown' }
        @{ Kind = 'object'; Explode = $false; Expected = 'R,100,G,200,B,150' }
        @{ Kind = 'object'; Explode = $true; Expected = 'R=100,G=200,B=150' }
    ) {
        $values = @{ string = 'blue'; array = @('blue', 'black', 'brown'); object = [ordered]@{ R = 100; G = 200; B = 150 } }
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Value = $values[$Kind]; Explode = $Explode; Expected = $Expected } {
            ConvertTo-OpenApiHeaderParameter -Value $Value -Explode:$Explode | Should -BeExactly $Expected
        }
    }

    It 'does not percent-encode and writes booleans in lower case' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiHeaderParameter -Value 'a b/c' | Should -BeExactly 'a b/c'
            ConvertTo-OpenApiHeaderParameter -Value $true | Should -BeExactly 'true'
            ConvertTo-OpenApiHeaderParameter -Value $null | Should -BeExactly ''
        }
    }
}
