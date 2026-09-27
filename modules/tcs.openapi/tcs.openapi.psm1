# Root folder of tcs.openapi, used to find the templates shipped with the module
$script:TcsOpenApiModuleRoot = $PSScriptRoot

#region load private and public functions
$Private = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Private') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.Tests.ps1' -and $_.FullName -notmatch '[\\/]Tests[\\/]' })
$Public = @(Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.Tests.ps1' -and $_.FullName -notmatch '[\\/]Tests[\\/]' })

foreach ($File in @($Private + $Public)) {
    try {
        . $File.FullName
    }
    catch {
        Write-Error -Message "Failed to import '$($File.FullName)': $_"
    }
}
#endregion

#region clean up when the module is removed
$ExecutionContext.SessionState.Module.OnRemove = {
    if (Get-Command -Name Clear-OpenApiHttpClientCache -ErrorAction SilentlyContinue) {
        Clear-OpenApiHttpClientCache
    }
}
#endregion

Export-ModuleMember -Function $Public.BaseName
