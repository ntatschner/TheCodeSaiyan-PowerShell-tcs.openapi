function Get-OpenApiContextStore {
    <#
    .SYNOPSIS
        Returns the module-scope hashtable of contexts keyed by service name, creating it on first use.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $store = Get-OpenApiModuleState -Name 'TcsOpenApiContexts'
    return $store
}
