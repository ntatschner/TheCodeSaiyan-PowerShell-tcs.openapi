function Get-OpenApiModuleState {
    <#
    .SYNOPSIS
        Returns a module-scope hashtable by name (contexts, HTTP clients, tokens, warnings), creating it on first use.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('TcsOpenApiContexts', 'TcsOpenApiHttpClients', 'TcsOpenApiTokenCache', 'TcsOpenApiDeprecationWarned')]
        [string]$Name
    )

    # PSVariable.Get does not write an error for a missing variable (Get-Variable would, even when silenced,
    # and that error would show up in the caller's -ErrorVariable)
    $variable = $ExecutionContext.SessionState.PSVariable.Get($Name)
    if ($null -eq $variable -or $variable.Value -isnot [hashtable]) {
        $state = @{}
        Set-Variable -Name $Name -Scope Script -Value $state
        return $state
    }
    return $variable.Value
}
