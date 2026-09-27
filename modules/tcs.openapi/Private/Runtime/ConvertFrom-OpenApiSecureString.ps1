function ConvertFrom-OpenApiSecureString {
    <#
    .SYNOPSIS
        Decodes a SecureString to plain text, only when a request is being built.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [System.Security.SecureString]$SecureString
    )

    if ($null -eq $SecureString) {
        return $null
    }
    return (New-Object System.Net.NetworkCredential -ArgumentList '', $SecureString).Password
}
