function Get-OpenApiParameterStyle {
    <#
    .SYNOPSIS
        Finds a parameter in the operation metadata by spec name and location and returns its effective Style, Explode, AllowReserved and CatchAll (a missing flag is false).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [object[]]$Parameter,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [ValidateSet('path', 'query', 'header', 'cookie')]
        [string]$In
    )

    $match = $null
    foreach ($candidate in @($Parameter)) {
        if ($null -eq $candidate) {
            continue
        }
        if ([string](Get-OpenApiMember -InputObject $candidate -Name 'Name') -eq $Name -and [string](Get-OpenApiMember -InputObject $candidate -Name 'In') -eq $In) {
            $match = $candidate
            break
        }
    }
    $resolved = Resolve-OpenApiParameterStyle -In $In -Style ([string](Get-OpenApiMember -InputObject $match -Name 'Style')) -Explode (Get-OpenApiMember -InputObject $match -Name 'Explode')
    $allowReserved = [bool](Get-OpenApiMember -InputObject $match -Name 'AllowReserved')
    $catchAll = [bool](Get-OpenApiMember -InputObject $match -Name 'CatchAll')
    return [pscustomobject]@{
        Name          = $Name
        In            = $In
        Style         = $resolved.Style
        Explode       = $resolved.Explode
        AllowReserved = $allowReserved
        CatchAll      = $catchAll
    }
}
