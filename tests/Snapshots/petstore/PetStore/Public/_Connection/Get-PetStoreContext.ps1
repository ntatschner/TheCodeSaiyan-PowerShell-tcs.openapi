function Get-PetStoreContext {
    <#
    .SYNOPSIS
        Returns the connection used by the PetStore commands, with secrets hidden.

    .DESCRIPTION
        Calls Get-OpenApiContext from tcs.openapi for the service 'PetStore'.

    .EXAMPLE
        Get-PetStoreContext

        Shows the connection of this session, with secrets hidden.

    .LINK
        Get-OpenApiContext
    #>
    [CmdletBinding()]
    param()

    Get-OpenApiContext -Service $script:TcsOpenApiService
}
