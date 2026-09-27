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

Describe 'Build-OpenApiBinaryContent' {
    It 'creates content from a byte array, a file, a stream and text' {
        InModuleScope -ModuleName tcs.openapi {
            $bytes = [byte[]](1, 2, 3)
            (Build-OpenApiBinaryContent -Value $bytes).ReadAsByteArrayAsync().GetAwaiter().GetResult() | Should -Be $bytes

            $path = Join-Path -Path $TestDrive -ChildPath 'b.bin'
            [System.IO.File]::WriteAllBytes($path, $bytes)
            $content = Build-OpenApiBinaryContent -Value (Get-Item -LiteralPath $path)
            $content.ReadAsByteArrayAsync().GetAwaiter().GetResult() | Should -Be $bytes
            $content.Dispose()

            $stream = New-Object System.IO.MemoryStream -ArgumentList (, $bytes)
            $stream.Position = 3
            (Build-OpenApiBinaryContent -Value $stream).ReadAsByteArrayAsync().GetAwaiter().GetResult() | Should -Be $bytes

            [System.Text.Encoding]::UTF8.GetString((Build-OpenApiBinaryContent -Value 'hi').ReadAsByteArrayAsync().GetAwaiter().GetResult()) | Should -Be 'hi'
            (Build-OpenApiBinaryContent -Value $null).ReadAsByteArrayAsync().GetAwaiter().GetResult().Length | Should -Be 0
        }
    }

    It 'throws FileNotFoundException for a missing file' {
        InModuleScope -ModuleName tcs.openapi {
            $missing = New-Object System.IO.FileInfo -ArgumentList (Join-Path -Path $TestDrive -ChildPath 'none.bin')
            { Build-OpenApiBinaryContent -Value $missing } | Should -Throw -ExceptionType ([System.IO.FileNotFoundException])
        }
    }
}
