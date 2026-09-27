<#
.SYNOPSIS
    Smoke tests for tcs.openapi, run by the shared CI validate workflow after the module import check.

.DESCRIPTION
    Imports the module from the repository, checks that the exports match the manifest, imports a tiny
    inline OpenAPI document, validates it and runs New-OpenApiModule -WhatIf (which must write nothing).
    Needs tcs.core 0.4.1 or later (the RequiredModule) to be installed. Offline and side-effect free.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$moduleName = 'tcs.openapi'
$repoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$moduleManifest = Join-Path -Path (Join-Path -Path (Join-Path -Path $repoRoot -ChildPath 'modules') -ChildPath $moduleName) -ChildPath "$moduleName.psd1"
if (-not (Test-Path -LiteralPath $moduleManifest)) {
    throw "Module manifest not found at path: $moduleManifest"
}

# Keep the smoke test offline and away from the real user profile
$env:TCS_SKIP_UPDATE_CHECK = '1'
$env:TCS_TELEMETRY_OPTOUT = '1'
$env:TCS_CONFIG_ROOT = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "tcs-openapi-smoke-$([guid]::NewGuid().ToString('N'))"
$outputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "tcs-openapi-smoke-out-$([guid]::NewGuid().ToString('N'))"

try {
    Write-Output "Importing $moduleName from $moduleManifest"
    $importOutput = @(& { Import-Module -Name $moduleManifest -Force -ErrorAction Stop } *>&1)
    if ($importOutput.Count -gt 0) {
        throw "Importing $moduleName wrote output: $($importOutput -join '; ')"
    }

    $expected = @((Import-PowerShellDataFile -Path $moduleManifest).FunctionsToExport | Sort-Object)
    $exported = @((Get-Module -Name $moduleName).ExportedFunctions.Keys | Sort-Object)
    if (($expected -join ',') -ne ($exported -join ',')) {
        throw "Exported functions ($($exported -join ', ')) do not match FunctionsToExport ($($expected -join ', '))."
    }
    Write-Output "Exports match the manifest: $($exported -join ', ')"

    $documentText = @'
{
  "openapi": "3.0.3",
  "info": { "title": "Smoke", "version": "1.0.0" },
  "servers": [ { "url": "https://smoke.example.com/api" } ],
  "paths": {
    "/widgets/{widgetId}": {
      "get": {
        "operationId": "getWidget",
        "parameters": [ { "name": "widgetId", "in": "path", "required": true, "schema": { "type": "string" } } ],
        "responses": { "200": { "description": "A widget", "content": { "application/json": { "schema": { "$ref": "#/components/schemas/Widget" } } } } }
      }
    }
  },
  "components": { "schemas": { "Widget": { "type": "object", "properties": { "id": { "type": "string" } } } } }
}
'@
    $document = Import-OpenApiDocument -InputObject $documentText
    if ($document.PSObject.TypeNames -notcontains 'Tcs.OpenApi.Document') {
        throw 'Import-OpenApiDocument did not return a Tcs.OpenApi.Document.'
    }
    if (@($document.Operations).Count -ne 1 -or $document.Operations[0].OperationId -ne 'getWidget') {
        throw 'Import-OpenApiDocument did not return the getWidget operation.'
    }

    $errors = @(Test-OpenApiDocument -Document $document | Where-Object -FilterScript { $_.Severity -eq 'Error' })
    if ($errors.Count -gt 0) {
        throw "Test-OpenApiDocument reported errors: $(($errors | ForEach-Object -Process { $_.Code }) -join ', ')"
    }

    $result = New-OpenApiModule -Document $document -ModuleName 'Smoke' -NounPrefix 'Smoke' -OutputPath $outputPath -WhatIf
    if (Test-Path -LiteralPath $outputPath) {
        throw 'New-OpenApiModule -WhatIf wrote files.'
    }
    $names = @($result.Functions | ForEach-Object -Process { $_.Name })
    foreach ($name in @('Get-SmokeWidget', 'Set-SmokeContext', 'Get-SmokeContext', 'Remove-SmokeContext')) {
        if ($names -notcontains $name) {
            throw "New-OpenApiModule -WhatIf did not plan $name (planned: $($names -join ', '))."
        }
    }
    Write-Output "New-OpenApiModule -WhatIf planned: $($names -join ', ')"
    Write-Output 'tcs.openapi smoke tests passed.'
}
finally {
    Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
    foreach ($path in @($env:TCS_CONFIG_ROOT, $outputPath)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}
