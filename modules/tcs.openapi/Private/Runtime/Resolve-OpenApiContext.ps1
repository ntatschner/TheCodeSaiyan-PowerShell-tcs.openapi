function Resolve-OpenApiContext {
    <#
    .SYNOPSIS
        Returns the context of a service from the module-scope store, loading a persisted one on first use; $null when there is none.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Service
    )

    $store = Get-OpenApiContextStore
    if ($store.ContainsKey($Service)) {
        return $store[$Service]
    }
    $context = Import-OpenApiPersistedContext -Service $Service
    if ($null -ne $context) {
        Write-Verbose -Message "Loaded the saved context of the '$Service' service."
        $store[$Service] = $context
    }
    return $context
}
