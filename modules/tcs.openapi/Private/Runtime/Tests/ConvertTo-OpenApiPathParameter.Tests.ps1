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

Describe 'ConvertTo-OpenApiPathParameter' {
    # OpenAPI 3.0.3 "Style Examples" table (https://spec.openapis.org/oas/v3.0.3#style-examples), path styles.
    # color: empty -> $null, string -> "blue", array -> ["blue","black","brown"], object -> { "R": 100, "G": 200, "B": 150 }
    It '<Style> explode=<Explode> renders <Kind> as <Expected>' -ForEach @(
        @{ Style = 'matrix'; Explode = $false; Kind = 'empty'; Expected = ';color' }
        @{ Style = 'matrix'; Explode = $false; Kind = 'string'; Expected = ';color=blue' }
        @{ Style = 'matrix'; Explode = $false; Kind = 'array'; Expected = ';color=blue,black,brown' }
        @{ Style = 'matrix'; Explode = $false; Kind = 'object'; Expected = ';color=R,100,G,200,B,150' }
        @{ Style = 'matrix'; Explode = $true; Kind = 'empty'; Expected = ';color' }
        @{ Style = 'matrix'; Explode = $true; Kind = 'string'; Expected = ';color=blue' }
        @{ Style = 'matrix'; Explode = $true; Kind = 'array'; Expected = ';color=blue;color=black;color=brown' }
        @{ Style = 'matrix'; Explode = $true; Kind = 'object'; Expected = ';R=100;G=200;B=150' }
        @{ Style = 'label'; Explode = $false; Kind = 'empty'; Expected = '.' }
        @{ Style = 'label'; Explode = $false; Kind = 'string'; Expected = '.blue' }
        @{ Style = 'label'; Explode = $false; Kind = 'array'; Expected = '.blue.black.brown' }
        @{ Style = 'label'; Explode = $false; Kind = 'object'; Expected = '.R.100.G.200.B.150' }
        @{ Style = 'label'; Explode = $true; Kind = 'empty'; Expected = '.' }
        @{ Style = 'label'; Explode = $true; Kind = 'string'; Expected = '.blue' }
        @{ Style = 'label'; Explode = $true; Kind = 'array'; Expected = '.blue.black.brown' }
        @{ Style = 'label'; Explode = $true; Kind = 'object'; Expected = '.R=100.G=200.B=150' }
        @{ Style = 'simple'; Explode = $false; Kind = 'string'; Expected = 'blue' }
        @{ Style = 'simple'; Explode = $false; Kind = 'array'; Expected = 'blue,black,brown' }
        @{ Style = 'simple'; Explode = $false; Kind = 'object'; Expected = 'R,100,G,200,B,150' }
        @{ Style = 'simple'; Explode = $true; Kind = 'string'; Expected = 'blue' }
        @{ Style = 'simple'; Explode = $true; Kind = 'array'; Expected = 'blue,black,brown' }
        @{ Style = 'simple'; Explode = $true; Kind = 'object'; Expected = 'R=100,G=200,B=150' }
    ) {
        $values = @{
            empty  = $null
            string = 'blue'
            array  = @('blue', 'black', 'brown')
            object = [ordered]@{ R = 100; G = 200; B = 150 }
        }
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Style = $Style; Explode = $Explode; Value = $values[$Kind]; Expected = $Expected } {
            ConvertTo-OpenApiPathParameter -Name 'color' -Value $Value -Style $Style -Explode:$Explode | Should -BeExactly $Expected
        }
    }

    It 'percent-encodes reserved characters in each segment value' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiPathParameter -Name 'id' -Value 'a/b c?#' | Should -BeExactly 'a%2Fb%20c%3F%23'
            ConvertTo-OpenApiPathParameter -Name 'id' -Value @('a,b', 'c') | Should -BeExactly 'a%2Cb,c'
        }
    }

    It 'writes booleans in lower case and dates as ISO 8601 round-trip' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiPathParameter -Name 'flag' -Value $true | Should -BeExactly 'true'
            $date = New-Object System.DateTime -ArgumentList 2024, 1, 2, 3, 4, 5, ([System.DateTimeKind]::Utc)
            ConvertTo-OpenApiPathParameter -Name 'when' -Value $date | Should -BeExactly '2024-01-02T03%3A04%3A05.0000000Z'
        }
    }

    It 'accepts a PSCustomObject as an object value' {
        InModuleScope -ModuleName tcs.openapi {
            ConvertTo-OpenApiPathParameter -Name 'color' -Value ([pscustomobject]@{ R = 1; G = 2 }) -Explode | Should -BeExactly 'R=1,G=2'
        }
    }
}
