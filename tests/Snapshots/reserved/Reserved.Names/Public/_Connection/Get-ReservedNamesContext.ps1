function Get-ReservedNamesContext {
    <#
    .SYNOPSIS
        Returns the connection used by the Reserved.Names commands, with secrets hidden.

    .DESCRIPTION
        Calls Get-OpenApiContext from tcs.openapi for the service 'Reserved.Names'.

    .EXAMPLE
        Get-ReservedNamesContext

        Shows the connection of this session, with secrets hidden.

    .LINK
        Get-OpenApiContext
    #>
    [CmdletBinding()]
    param()

    Get-OpenApiContext -Service $script:TcsOpenApiService
}
