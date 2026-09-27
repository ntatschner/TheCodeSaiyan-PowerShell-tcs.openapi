function Read-OpenApiResponseBody {
    <#
    .SYNOPSIS
        Reads the whole body of a response object into its Body property (byte[]) and disposes the underlying message.
    #>
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Response
    )

    if ($null -eq $Response.Body -and $null -ne $Response.Message) {
        try {
            if ($null -ne $Response.Message.Content) {
                $Response.Body = $Response.Message.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
            }
            else {
                $Response.Body = [byte[]]@()
            }
        }
        finally {
            $Response.Message.Dispose()
            $Response.Message = $null
        }
    }
    if ($null -eq $Response.Body) {
        $Response.Body = [byte[]]@()
    }
    return , [byte[]]$Response.Body
}
