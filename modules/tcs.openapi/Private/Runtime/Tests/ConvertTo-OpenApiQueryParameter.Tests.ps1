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

Describe 'ConvertTo-OpenApiQueryParameter' {
    # OpenAPI 3.0.3 "Style Examples" table (https://spec.openapis.org/oas/v3.0.3#style-examples), query styles.
    # The table shows spaceDelimited/pipeDelimited values without the name; in a query they follow 'color='.
    It '<Style> explode=<Explode> renders <Kind> as <Expected>' -ForEach @(
        @{ Style = 'form'; Explode = $false; Kind = 'empty'; Expected = 'color=' }
        @{ Style = 'form'; Explode = $false; Kind = 'string'; Expected = 'color=blue' }
        @{ Style = 'form'; Explode = $false; Kind = 'array'; Expected = 'color=blue,black,brown' }
        @{ Style = 'form'; Explode = $false; Kind = 'object'; Expected = 'color=R,100,G,200,B,150' }
        @{ Style = 'form'; Explode = $true; Kind = 'empty'; Expected = 'color=' }
        @{ Style = 'form'; Explode = $true; Kind = 'string'; Expected = 'color=blue' }
        @{ Style = 'form'; Explode = $true; Kind = 'array'; Expected = 'color=blue&color=black&color=brown' }
        @{ Style = 'form'; Explode = $true; Kind = 'object'; Expected = 'R=100&G=200&B=150' }
        @{ Style = 'spaceDelimited'; Explode = $false; Kind = 'array'; Expected = 'color=blue%20black%20brown' }
        @{ Style = 'spaceDelimited'; Explode = $false; Kind = 'object'; Expected = 'color=R%20100%20G%20200%20B%20150' }
        @{ Style = 'pipeDelimited'; Explode = $false; Kind = 'array'; Expected = 'color=blue|black|brown' }
        @{ Style = 'pipeDelimited'; Explode = $false; Kind = 'object'; Expected = 'color=R|100|G|200|B|150' }
        @{ Style = 'deepObject'; Explode = $true; Kind = 'object'; Expected = 'color%5BR%5D=100&color%5BG%5D=200&color%5BB%5D=150' }  # the spec shows color[R]=100; brackets are percent-encoded so both editions send the same query
    ) {
        $values = @{
            empty  = $null
            string = 'blue'
            array  = @('blue', 'black', 'brown')
            object = [ordered]@{ R = 100; G = 200; B = 150 }
        }
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Style = $Style; Explode = $Explode; Value = $values[$Kind]; Expected = $Expected } {
            (ConvertTo-OpenApiQueryParameter -Name 'color' -Value $Value -Style $Style -Explode:$Explode) -join '&' | Should -BeExactly $Expected
        }
    }

    It 'treats an empty string and an empty array as empty' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertTo-OpenApiQueryParameter -Name 'q' -Value '') -join '&' | Should -BeExactly 'q='
            (ConvertTo-OpenApiQueryParameter -Name 'q' -Value @()) -join '&' | Should -BeExactly 'q='
        }
    }

    It 'percent-encodes reserved characters unless allowReserved is set' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertTo-OpenApiQueryParameter -Name 'filter' -Value 'a/b:c d&e') -join '&' | Should -BeExactly 'filter=a%2Fb%3Ac%20d%26e'
            (ConvertTo-OpenApiQueryParameter -Name 'filter' -Value 'a/b:c d' -AllowReserved) -join '&' | Should -BeExactly 'filter=a/b:c%20d'
        }
    }

    It 'encodes non-ASCII text as UTF-8' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertTo-OpenApiQueryParameter -Name 'name' -Value ([string][char]0x00E9)) -join '&' | Should -BeExactly 'name=%C3%A9'
        }
    }

    It 'writes booleans in lower case, dates as ISO 8601 and numbers with the invariant culture' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertTo-OpenApiQueryParameter -Name 'on' -Value $false) -join '&' | Should -BeExactly 'on=false'
            $date = New-Object System.DateTime -ArgumentList 2024, 5, 6, 7, 8, 9, ([System.DateTimeKind]::Utc)
            (ConvertTo-OpenApiQueryParameter -Name 'since' -Value $date) -join '&' | Should -BeExactly 'since=2024-05-06T07%3A08%3A09.0000000Z'
            (ConvertTo-OpenApiQueryParameter -Name 'n' -Value 1.5) -join '&' | Should -BeExactly 'n=1.5'
        }
    }

    It 'nests deepObject values and repeats arrays' {
        InModuleScope -ModuleName tcs.openapi {
            $value = [ordered]@{ a = [ordered]@{ b = 1 }; tags = @('x', 'y') }
            (ConvertTo-OpenApiQueryParameter -Name 'f' -Value $value -Style 'deepObject' -Explode) -join '&' | Should -BeExactly 'f%5Ba%5D%5Bb%5D=1&f%5Btags%5D=x&f%5Btags%5D=y'
        }
    }

    It 'uses the form style for a scalar with a delimited style' {
        InModuleScope -ModuleName tcs.openapi {
            (ConvertTo-OpenApiQueryParameter -Name 'c' -Value 'blue' -Style 'pipeDelimited') -join '&' | Should -BeExactly 'c=blue'
        }
    }
}
