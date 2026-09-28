function Remove-PetStoreContext {
    <#
    .SYNOPSIS
        Removes the connection used by the PetStore commands.

    .DESCRIPTION
        Calls Remove-OpenApiContext from tcs.openapi for the service 'PetStore'.

    .PARAMETER Persisted
        Also removes the saved connection and its secrets.

    .EXAMPLE
        Remove-PetStoreContext -Persisted

        Removes the connection of this session and the saved connection.

    .LINK
        Remove-OpenApiContext
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter()]
        [switch]
        $Persisted
    )

    $tcsContext = @{ Service = $script:TcsOpenApiService }
    foreach ($tcsName in @($PSBoundParameters.Keys)) {
        if (@('WhatIf', 'Confirm') -notcontains $tcsName) {
            $tcsContext[$tcsName] = $PSBoundParameters[$tcsName]
        }
    }
    if ($PSCmdlet.ShouldProcess($script:TcsOpenApiService, 'Remove the API connection')) {
        Remove-OpenApiContext @tcsContext
    }
}
