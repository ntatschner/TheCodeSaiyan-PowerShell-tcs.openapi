<#
.SYNOPSIS
    Regenerates the generator snapshots in tests/Snapshots from the hand-built document models.

.DESCRIPTION
    Imports tcs.openapi from this repository, builds the three models from New-TestOpenApiModel.ps1
    and writes each generated module to tests/Snapshots/<Name>/<ModuleName>, replacing what is there.
    Run it after a deliberate change to the generator or its templates, review the diff and commit
    it with the change. tests/Generator.Snapshot.Tests.ps1 compares fresh output with these files.
    Needs tcs.core 0.4.0 on PSModulePath. Works without Build.ps1.

.EXAMPLE
    ./tests/Helpers/Update-Snapshots.ps1
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param()

$repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$env:TCS_SKIP_UPDATE_CHECK = '1'
$env:TCS_TELEMETRY_OPTOUT = '1'
Import-Module -Name (Join-Path -Path $repoRoot -ChildPath 'modules/tcs.openapi/tcs.openapi.psd1') -Force
. (Join-Path -Path $PSScriptRoot -ChildPath 'New-TestOpenApiModel.ps1')

$snapshotRoot = Join-Path -Path (Join-Path -Path $repoRoot -ChildPath 'tests') -ChildPath 'Snapshots'
foreach ($case in Get-TestSnapshotCase) {
    $target = Join-Path -Path $snapshotRoot -ChildPath $case.Name
    if ($PSCmdlet.ShouldProcess($target, 'Regenerate snapshot')) {
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Recurse -Force
        }
        $parameters = @{
            Document   = (New-TestOpenApiModel -Name $case.Name)
            ModuleName = $case.ModuleName
            OutputPath = $target
        }
        if ($case.NounPrefix) {
            $parameters['NounPrefix'] = $case.NounPrefix
        }
        $result = New-OpenApiModule @parameters
        Write-Verbose -Message "$($case.Name): $(@($result.Files).Count) files in $($result.Path)"
    }
}
