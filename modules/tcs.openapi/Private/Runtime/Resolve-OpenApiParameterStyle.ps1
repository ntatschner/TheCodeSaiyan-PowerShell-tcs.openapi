function Resolve-OpenApiParameterStyle {
    <#
    .SYNOPSIS
        Returns the effective Style and Explode of a parameter, applying the OpenAPI defaults for its location.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('path', 'query', 'header', 'cookie')]
        [string]$In,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Style,

        [Parameter()]
        [AllowNull()]
        [object]$Explode
    )

    if ([string]::IsNullOrEmpty($Style)) {
        if ($In -eq 'query' -or $In -eq 'cookie') {
            $Style = 'form'
        }
        else {
            $Style = 'simple'
        }
    }
    if ($null -eq $Explode -or ($Explode -is [string] -and $Explode.Length -eq 0)) {
        $Explode = ($Style -eq 'form' -or $Style -eq 'deepObject')
    }
    return [pscustomobject]@{
        Style   = $Style
        Explode = [bool]$Explode
    }
}
