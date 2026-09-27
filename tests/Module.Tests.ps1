# Repository-wide guards for the tcs.openapi module: manifest, exports, help, naming and file encoding.

BeforeDiscovery {
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent
    $moduleRoot = Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi'
    $publicNames = @(Get-ChildItem -LiteralPath (Join-Path -Path $moduleRoot -ChildPath 'Public') -Filter '*.ps1' -File |
            Where-Object -FilterScript { $_.Name -notlike '*.Tests.ps1' } | ForEach-Object -Process { @{ Name = $_.BaseName } })
}

BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $RepoRoot = Split-Path -Path $PSScriptRoot -Parent
    $ModuleRoot = Join-Path -Path $RepoRoot -ChildPath 'modules/tcs.openapi'
    $ManifestPath = Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1'
    Import-Module -Name $ManifestPath -Force

    # Every PowerShell file of the module that is not a test, with the functions it defines
    $SourceFiles = @(Get-ChildItem -LiteralPath $ModuleRoot -Recurse -File -Include '*.ps1', '*.psm1' |
            Where-Object -FilterScript { $_.Name -notlike '*.Tests.ps1' -and $_.FullName -notmatch '[\\/]Tests[\\/]' })
    $FunctionDefinitions = @(foreach ($file in $SourceFiles) {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
            foreach ($function in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)) {
                [pscustomobject]@{ Name = $function.Name; File = $file.FullName; Nested = ($null -ne $function.Parent -and $function.Parent -isnot [System.Management.Automation.Language.NamedBlockAst]) }
            }
        })
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'tcs.openapi manifest and import' {
    It 'has a valid manifest' {
        $problems = $null
        $manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction SilentlyContinue -ErrorVariable problems
        # Test-ModuleManifest looks RequiredAssemblies up in the GAC, which exists only on Windows;
        # System.Net.Http loads by name everywhere (the import test below proves it)
        $isWindowsOs = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
        $problems = @($problems | Where-Object -FilterScript { $isWindowsOs -or $_.FullyQualifiedErrorId -notlike 'Modules_InvalidRequiredAssembliesInModuleManifest*' })
        ($problems | ForEach-Object -Process { $_.Exception.Message }) -join "`n" | Should -BeNullOrEmpty
        $manifest.Name | Should -Be 'tcs.openapi'
        $manifest.Version | Should -Not -BeNullOrEmpty
    }

    It 'requires tcs.core 0.4.1 and System.Net.Http' {
        $data = Import-PowerShellDataFile -Path $ManifestPath
        $data.RequiredModules | Should -HaveCount 1
        $data.RequiredModules[0].ModuleName | Should -Be 'tcs.core'
        $data.RequiredModules[0].ModuleVersion | Should -Be '0.4.1'
        $data.RequiredAssemblies | Should -Contain 'System.Net.Http'
        $data.PowerShellVersion | Should -Be '5.1'
        $data.CompatiblePSEditions | Should -Be @('Desktop', 'Core')
    }

    It 'imports without writing anything to any stream' {
        Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
        $output = @(& { Import-Module -Name $ManifestPath -Force } *>&1)
        $output | Should -BeNullOrEmpty
    }

    It 'exports exactly FunctionsToExport, which are exactly the Public/*.ps1 files' {
        $publicFiles = @(Get-ChildItem -LiteralPath (Join-Path -Path $ModuleRoot -ChildPath 'Public') -Filter '*.ps1' -File |
                Where-Object -FilterScript { $_.Name -notlike '*.Tests.ps1' } | ForEach-Object -Process { $_.BaseName } | Sort-Object)
        $manifestExports = @((Import-PowerShellDataFile -Path $ManifestPath).FunctionsToExport | Sort-Object)
        $moduleExports = @((Get-Module -Name tcs.openapi).ExportedFunctions.Keys | Sort-Object)
        $manifestExports | Should -Be $publicFiles
        $moduleExports | Should -Be $publicFiles
        (Get-Module -Name tcs.openapi).ExportedCmdlets.Count | Should -Be 0
        (Get-Module -Name tcs.openapi).ExportedAliases.Count | Should -Be 0
        (Get-Module -Name tcs.openapi).ExportedVariables.Count | Should -Be 0
    }
}

Describe 'tcs.openapi functions' {
    It 'no two files define the same function' {
        $duplicates = @($FunctionDefinitions | Where-Object -FilterScript { -not $_.Nested } | Group-Object -Property Name | Where-Object -FilterScript { $_.Count -gt 1 } |
                ForEach-Object -Process { "$($_.Name): $(($_.Group.File | ForEach-Object -Process { Split-Path -Path $_ -Leaf }) -join ', ')" })
        $duplicates | Should -BeNullOrEmpty
    }

    It 'every file under Public and Private defines one function named like the file' {
        $problems = @(foreach ($file in $SourceFiles | Where-Object -FilterScript { $_.Extension -eq '.ps1' }) {
                $names = @($FunctionDefinitions | Where-Object -FilterScript { $_.File -eq $file.FullName -and -not $_.Nested } | ForEach-Object -Process { $_.Name })
                if ($names.Count -ne 1 -or $names[0] -ne $file.BaseName) {
                    "$($file.Name): $($names -join ', ')"
                }
            })
        $problems | Should -BeNullOrEmpty
    }

    It 'every function, public and private, uses an approved verb' {
        $approved = @(Get-Verb | ForEach-Object -Process { $_.Verb })
        $unapproved = @($FunctionDefinitions | Where-Object -FilterScript { $approved -notcontains ($_.Name -split '-')[0] } | ForEach-Object -Process { $_.Name })
        $unapproved | Should -BeNullOrEmpty
    }

    It 'every Public and Private function has a Tests file next to it' {
        $missing = @(foreach ($file in $SourceFiles | Where-Object -FilterScript { $_.Extension -eq '.ps1' }) {
                $test = Join-Path -Path (Join-Path -Path $file.DirectoryName -ChildPath 'Tests') -ChildPath "$($file.BaseName).Tests.ps1"
                if (-not (Test-Path -LiteralPath $test)) {
                    $file.Name
                }
            })
        $missing | Should -BeNullOrEmpty
    }
}

Describe 'Help of <Name>' -ForEach $publicNames {
    BeforeAll {
        $help = Get-Help -Name $Name -Full
        $command = Get-Command -Name $Name
        $common = @([System.Management.Automation.PSCmdlet]::CommonParameters) + @([System.Management.Automation.PSCmdlet]::OptionalCommonParameters)
    }

    It 'has a synopsis' {
        $help.Synopsis | Should -Not -BeNullOrEmpty
        # Without comment-based help PowerShell shows the syntax as the synopsis
        $help.Synopsis | Should -Not -Match "^\s*$Name "
    }

    It 'has a description' {
        ($help.Description | ForEach-Object -Process { $_.Text }) -join '' | Should -Not -BeNullOrEmpty
    }

    It 'has at least one example with code' {
        @($help.Examples.Example).Count | Should -BeGreaterThan 0
        @($help.Examples.Example)[0].Code | Should -Not -BeNullOrEmpty
    }

    It 'documents every parameter' {
        $undocumented = @(foreach ($parameter in $command.Parameters.Keys | Where-Object -FilterScript { $common -notcontains $_ }) {
                $entry = @($help.Parameters.Parameter | Where-Object -FilterScript { $_.Name -eq $parameter })
                if ($entry.Count -eq 0 -or -not (($entry[0].Description | ForEach-Object -Process { $_.Text }) -join '')) {
                    $parameter
                }
            })
        $undocumented | Should -BeNullOrEmpty
    }
}

Describe 'about_tcs.openapi help' {
    It 'exists in en-GB and en-US with identical content' {
        $gb = Join-Path -Path $ModuleRoot -ChildPath 'en-GB/about_tcs.openapi.help.txt'
        $us = Join-Path -Path $ModuleRoot -ChildPath 'en-US/about_tcs.openapi.help.txt'
        Test-Path -LiteralPath $gb | Should -BeTrue
        Test-Path -LiteralPath $us | Should -BeTrue
        [System.IO.File]::ReadAllBytes($us) | Should -Be ([System.IO.File]::ReadAllBytes($gb))
    }

    It 'is found by Get-Help' {
        $text = (Get-Help -Name 'about_tcs.openapi' -ErrorAction SilentlyContinue | Out-String)
        $text | Should -Match 'TOPIC'
        $text | Should -Match 'New-OpenApiModule'
    }
}

Describe 'Repository files' {
    BeforeAll {
        $textExtensions = @('.ps1', '.psm1', '.psd1', '.md', '.json', '.yaml', '.yml', '.txt', '.template', '.xml', '.editorconfig', '.gitattributes', '.gitignore')
        $TextFiles = @(Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -Force |
                Where-Object -FilterScript { $_.FullName -notmatch '[\\/]\.git[\\/]' -and ($textExtensions -contains $_.Extension -or $textExtensions -contains $_.Name) -and $_.Name -ne 'TestResults.xml' })
    }

    It 'finds the text files of the repository' {
        $TextFiles.Count | Should -BeGreaterThan 100
    }

    It 'saves every file with non-ASCII characters as UTF-8 with a BOM' {
        $problems = @(foreach ($file in $TextFiles) {
                $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
                $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
                # Latin-1 maps every byte to one character, so this finds any byte above 0x7F
                if (-not $hasBom -and [System.Text.Encoding]::GetEncoding(28591).GetString($bytes) -match '[\u0080-\u00FF]') {
                    $file.FullName.Substring($RepoRoot.Length + 1)
                }
            })
        $problems | Should -BeNullOrEmpty
    }
}
