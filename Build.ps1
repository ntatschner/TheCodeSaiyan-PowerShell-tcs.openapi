<#
.SYNOPSIS
    Build and test script for the tcs.openapi PowerShell module.

.DESCRIPTION
    This script provides various functions for building, testing, and preparing the tcs.openapi module
    for publication. It can validate the module, run tests, update versions, and prepare releases.

.PARAMETER Task
    The task to perform. Valid options:
    - Validate: Run all validation checks
    - Test: Run validation and Pester tests
    - UpdateVersion: Update the module version
    - PrepareRelease: Prepare for a new release
    - Clean: Clean up build artifacts

.PARAMETER Version
    The new version to set (used with UpdateVersion task)

.PARAMETER WhatIf
    Show what would be done without actually doing it

.EXAMPLE
    .\Build.ps1 -Task Validate
    Runs validation checks on the module

.EXAMPLE
    .\Build.ps1 -Task UpdateVersion -Version "0.1.8"
    Updates the module version to 0.1.8

.EXAMPLE
    .\Build.ps1 -Task PrepareRelease -Version "0.1.8"
    Prepares a new release with version 0.1.8
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Validate', 'Test', 'UpdateVersion', 'PrepareRelease', 'Clean', 'Help')]
    [string]$Task,

    [string]$Version,

    [switch]$WhatIf
)

$ModuleName = 'tcs.openapi'
$ModulePath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath 'modules') -ChildPath $ModuleName
$PesterVersion = '5.7.1'
$ManifestPath = Join-Path $ModulePath "$ModuleName.psd1"

function Write-TaskHeader {
    param([string]$Title)
    Write-Host "`n$('=' * 50)" -ForegroundColor Cyan
    Write-Host $Title.ToUpper() -ForegroundColor Cyan
    Write-Host $('=' * 50) -ForegroundColor Cyan
}

function Write-BuildSuccess {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-BuildWarning {
    param([string]$Message)
    Write-Host "⚠️ $Message" -ForegroundColor Yellow
}

function Write-BuildError {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Test-ModuleValidation {
    Write-TaskHeader "Module Validation"

    Write-Host "Testing module manifest..." -ForegroundColor Gray
    if (-not (Test-Path $ManifestPath)) {
        Write-BuildError "Module manifest not found at: $ManifestPath"
        return $false
    }

    try {
        $manifest = Test-ModuleManifest -Path $ManifestPath -ErrorAction Stop
        Write-BuildSuccess "Module manifest is valid"
        Write-Host "  Module: $($manifest.Name)" -ForegroundColor Gray
        Write-Host "  Version: $($manifest.Version)" -ForegroundColor Gray
        Write-Host "  Author: $($manifest.Author)" -ForegroundColor Gray
    }
    catch {
        Write-BuildError "Module manifest validation failed: $_"
        return $false
    }

    Write-Host "Testing module import..." -ForegroundColor Gray
    try {
        $env:TCS_SKIP_UPDATE_CHECK = '1'
        Import-Module $ManifestPath -Force -ErrorAction Stop
        Write-BuildSuccess "Module imports successfully"

        $exportedFunctions = (Get-Module $ModuleName).ExportedFunctions
        Write-Host "  Exported functions: $($exportedFunctions.Keys -join ', ')" -ForegroundColor Gray

        Remove-Module $ModuleName -Force
    }
    catch {
        Write-BuildError "Module import failed: $_"
        return $false
    }

    return $true
}

function Test-ScriptAnalyzer {
    Write-TaskHeader "PSScriptAnalyzer"

    if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
        Write-Host "Installing PSScriptAnalyzer..." -ForegroundColor Gray
        Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
    }

    $settingsPath = Join-Path $PSScriptRoot 'PSScriptAnalyzerSettings.psd1'
    $analyzerParams = @{
        Path      = $ModulePath
        Recurse   = $true
        Severity  = @('Warning', 'Error')
    }
    if (Test-Path $settingsPath) {
        $analyzerParams['Settings'] = $settingsPath
    }

    # Pester files are excluded: PSScriptAnalyzer cannot follow Pester's block scoping
    $results = Invoke-ScriptAnalyzer @analyzerParams | Where-Object { $_.ScriptName -notlike '*.Tests.ps1' }

    if ($results) {
        $errors = ($results | Where-Object Severity -eq 'Error').Count
        $warnings = ($results | Where-Object Severity -eq 'Warning').Count

        Write-Host "Found $errors error(s) and $warnings warning(s):" -ForegroundColor Yellow
        $results | Format-Table ScriptName, Line, Column, RuleName, Message -Wrap

        # Warnings fail the build as well, matching CI
        Write-BuildError "PSScriptAnalyzer found $errors error(s) and $warnings warning(s)"
        return $false
    } else {
        Write-BuildSuccess "No PSScriptAnalyzer issues found"
    }

    return $true
}

function Invoke-PesterTests {
    Write-TaskHeader "Pester Tests"

    if (-not (Get-Module -ListAvailable Pester | Where-Object Version -EQ $PesterVersion)) {
        Write-Host "Installing Pester $PesterVersion..." -ForegroundColor Gray
        Install-Module Pester -RequiredVersion $PesterVersion -Force -SkipPublisherCheck -Scope CurrentUser
    }
    Import-Module Pester -RequiredVersion $PesterVersion -Force

    # Keep test runs offline and away from the real user profile
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'

    $pesterConfig = New-PesterConfiguration
    $pesterConfig.Run.Path = @($ModulePath, (Join-Path $PSScriptRoot 'tests'))
    $pesterConfig.Run.Exit = $false
    $pesterConfig.Run.PassThru = $true
    $pesterConfig.Output.Verbosity = 'Normal'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = Join-Path $PSScriptRoot 'TestResults.xml'
    $pesterConfig.TestResult.OutputFormat = 'JUnitXml'

    $result = Invoke-Pester -Configuration $pesterConfig

    if ($result.FailedCount -gt 0) {
        Write-BuildError "$($result.FailedCount) Pester test(s) failed"
        return $false
    }

    Write-BuildSuccess "All $($result.PassedCount) Pester tests passed"
    return $true
}

function Update-ModuleVersion {
    param([string]$NewVersion)

    Write-TaskHeader "Update Module Version"

    if (-not $NewVersion) {
        Write-BuildError "Version parameter is required"
        return $false
    }

    if (-not ($NewVersion -match '^\d+\.\d+\.\d+$')) {
        Write-BuildError "Version must be in format x.y.z (e.g., 0.1.8)"
        return $false
    }

    Write-Host "Updating version to $NewVersion..." -ForegroundColor Gray

    if ($WhatIf) {
        Write-Host "WHATIF: Would update version in $ManifestPath" -ForegroundColor Yellow
        return $true
    }

    $manifestContent = Get-Content $ManifestPath -Raw
    $manifestContent = $manifestContent -replace "ModuleVersion\s*=\s*'[\d\.]+'", "ModuleVersion        = '$NewVersion'"
    $manifestContent = $manifestContent -replace "ReleaseNotes\s*=\s*'[^']*'", "ReleaseNotes = 'Version $NewVersion release'"
    Set-Content -Path $ManifestPath -Value $manifestContent -Encoding UTF8

    Write-BuildSuccess "Version updated to $NewVersion"
    return $true
}

function Invoke-PrepareRelease {
    param([string]$NewVersion)

    Write-TaskHeader "Prepare Release"

    if (-not $NewVersion) {
        Write-BuildError "Version parameter is required"
        return $false
    }

    if (-not (Update-ModuleVersion -NewVersion $NewVersion)) { return $false }
    if (-not (Test-ModuleValidation)) {
        Write-BuildError "Validation failed after version update"
        return $false
    }
    if (-not (Invoke-PesterTests)) {
        Write-BuildError "Tests failed after version update"
        return $false
    }

    Write-BuildSuccess "Release preparation complete"
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Review the changes: git diff" -ForegroundColor Gray
    Write-Host "2. Commit: git add . && git commit -m 'Release v$NewVersion'" -ForegroundColor Gray
    Write-Host "3. Tag: git tag v$NewVersion && git push origin main && git push origin v$NewVersion" -ForegroundColor Gray
    Write-Host "4. GitHub Actions will automatically publish to PowerShell Gallery" -ForegroundColor Gray

    return $true
}

function Invoke-Clean {
    Write-TaskHeader "Clean Build Artifacts"

    $itemsToClean = @("*.log", "TestResults.xml", "temp")

    foreach ($item in $itemsToClean) {
        $path = Join-Path $PSScriptRoot $item
        if (Test-Path $path) {
            if ($WhatIf) {
                Write-Host "WHATIF: Would remove $path" -ForegroundColor Yellow
            } else {
                Remove-Item $path -Recurse -Force
                Write-Host "Removed: $path" -ForegroundColor Gray
            }
        }
    }

    Write-BuildSuccess "Clean complete"
    return $true
}

function Show-Help {
    Write-TaskHeader "Build Script Help"

    Write-Host "Available tasks:" -ForegroundColor White
    Write-Host "  Validate       - Run module validation checks" -ForegroundColor Gray
    Write-Host "  Test           - Run validation and Pester tests" -ForegroundColor Gray
    Write-Host "  UpdateVersion  - Update the module version" -ForegroundColor Gray
    Write-Host "  PrepareRelease - Prepare for a new release" -ForegroundColor Gray
    Write-Host "  Clean          - Clean up build artifacts" -ForegroundColor Gray
    Write-Host "  Help           - Show this help message" -ForegroundColor Gray

    Write-Host "`nExamples:" -ForegroundColor White
    Write-Host "  .\Build.ps1 -Task Validate" -ForegroundColor Gray
    Write-Host "  .\Build.ps1 -Task Test" -ForegroundColor Gray
    Write-Host "  .\Build.ps1 -Task UpdateVersion -Version '0.1.8'" -ForegroundColor Gray
    Write-Host "  .\Build.ps1 -Task PrepareRelease -Version '0.1.8'" -ForegroundColor Gray
}

switch ($Task) {
    'Validate' {
        # Parentheses are required: without them '-and' is passed to the function as an argument
        $success = (Test-ModuleValidation) -and (Test-ScriptAnalyzer)
        exit $(if ($success) { 0 } else { 1 })
    }
    'Test' {
        # Parentheses are required: without them '-and' is passed to the function as an argument
        $success = (Test-ModuleValidation) -and (Test-ScriptAnalyzer) -and (Invoke-PesterTests)
        exit $(if ($success) { 0 } else { 1 })
    }
    'UpdateVersion' {
        $success = Update-ModuleVersion -NewVersion $Version
        exit $(if ($success) { 0 } else { 1 })
    }
    'PrepareRelease' {
        $success = Invoke-PrepareRelease -NewVersion $Version
        exit $(if ($success) { 0 } else { 1 })
    }
    'Clean' {
        $success = Invoke-Clean
        exit $(if ($success) { 0 } else { 1 })
    }
    'Help' {
        Show-Help
        exit 0
    }
}
