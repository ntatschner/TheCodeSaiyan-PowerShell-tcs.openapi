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

Describe 'ConvertTo-OpenApiScalarString' {
    It 'converts <Label>' -ForEach @(
        @{ Label = 'true'; Value = $true; Expected = 'true' }
        @{ Label = 'false'; Value = $false; Expected = 'false' }
        @{ Label = 'a switch'; Value = [switch]$true; Expected = 'true' }
        @{ Label = 'a double'; Value = 1.25; Expected = '1.25' }
        @{ Label = 'a long'; Value = [long]9007199254740993; Expected = '9007199254740993' }
        @{ Label = 'a string'; Value = 'x'; Expected = 'x' }
        @{ Label = '$null'; Value = $null; Expected = '' }
        @{ Label = 'a DateTimeOffset'; Value = [System.DateTimeOffset]::new(2024, 1, 2, 3, 4, 5, [timespan]::FromHours(2)); Expected = '2024-01-02T03:04:05.0000000+02:00' }
        @{ Label = 'a guid'; Value = [guid]'d3b07384-d9a0-4c9b-8c4e-4a4a4a4a4a4a'; Expected = 'd3b07384-d9a0-4c9b-8c4e-4a4a4a4a4a4a' }
        @{ Label = 'an object (as JSON)'; Value = [ordered]@{ a = 1 }; Expected = '{"a":1}' }
    ) {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ Value = $Value; Expected = $Expected } {
            ConvertTo-OpenApiScalarString -Value $Value | Should -BeExactly $Expected
        }
    }

    It 'formats numbers with the invariant culture' {
        InModuleScope -ModuleName tcs.openapi {
            $saved = [System.Threading.Thread]::CurrentThread.CurrentCulture
            try {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('de-DE')
                ConvertTo-OpenApiScalarString -Value 1.5 | Should -BeExactly '1.5'
            }
            finally {
                [System.Threading.Thread]::CurrentThread.CurrentCulture = $saved
            }
        }
    }

    It 'writes a UTC date with the Z suffix' {
        InModuleScope -ModuleName tcs.openapi {
            $date = New-Object System.DateTime -ArgumentList 2024, 1, 2, 3, 4, 5, ([System.DateTimeKind]::Utc)
            ConvertTo-OpenApiScalarString -Value $date | Should -BeExactly '2024-01-02T03:04:05.0000000Z'
        }
    }
}
