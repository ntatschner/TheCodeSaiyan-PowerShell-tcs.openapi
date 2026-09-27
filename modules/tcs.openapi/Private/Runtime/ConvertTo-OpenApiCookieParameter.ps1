function ConvertTo-OpenApiCookieParameter {
    <#
    .SYNOPSIS
        Serialises a cookie parameter with the form style; returns name=value pairs for one Cookie header.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [AllowNull()]
        [object]$Value,

        [Parameter()]
        [switch]$Explode
    )

    # Cookies use the form style; pairs are joined with '; ' into one Cookie header by the caller
    $pairs = ConvertTo-OpenApiQueryParameter -Name $Name -Value $Value -Style 'form' -Explode:$Explode
    return , @($pairs)
}
