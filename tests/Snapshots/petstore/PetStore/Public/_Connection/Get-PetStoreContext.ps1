function Get-PetStoreContext {
    <#
    .SYNOPSIS
        Returns the connection used by the PetStore commands, with secrets hidden.

    .DESCRIPTION
        Calls Get-OpenApiContext from tcs.openapi for the service 'PetStore'.

    .EXAMPLE
        Get-PetStoreContext

    .LINK
        Get-OpenApiContext
    #>
    [CmdletBinding()]
    param()

    Get-OpenApiContext -Service $script:TcsOpenApiService
}
