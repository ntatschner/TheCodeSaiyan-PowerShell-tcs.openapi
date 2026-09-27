function Get-ShopContext {
    <#
    .SYNOPSIS
        Returns the connection used by the Shop commands, with secrets hidden.

    .DESCRIPTION
        Calls Get-OpenApiContext from tcs.openapi for the service 'Shop'.

    .EXAMPLE
        Get-ShopContext

    .LINK
        Get-OpenApiContext
    #>
    [CmdletBinding()]
    param()

    Get-OpenApiContext -Service $script:TcsOpenApiService
}
