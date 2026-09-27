function Select-OpenApiSecurityRequirement {
    <#
    .SYNOPSIS
        Picks the first security requirement of an operation whose schemes all have credentials in the context.
    .DESCRIPTION
        Returns an object with Mode and Schemes:
          None        - the operation needs no credentials (Security = [] or an empty requirement was chosen)
          Selected    - Schemes lists { Name, Scheme, Scopes } of the chosen requirement
          Generic     - the metadata has no security information; the context's bearer token or credential is used
          Unsatisfied - no requirement can be met with the context's credentials
        Security = $null means the document default: the metadata's DefaultSecurity when present, else each scheme
        in SecuritySchemes on its own, in name order.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Operation,

        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    $schemes = Get-OpenApiMember -InputObject $Operation -Name 'SecuritySchemes'
    $security = Get-OpenApiMember -InputObject $Operation -Name 'Security'
    if ($null -eq $security) {
        $security = Get-OpenApiMember -InputObject $Operation -Name 'DefaultSecurity'
    }
    if ($null -eq $security) {
        $schemeNames = @(ConvertTo-OpenApiPropertyList -InputObject $schemes | ForEach-Object -Process { $_.Name } | Sort-Object)
        if ($schemeNames.Count -eq 0) {
            return [pscustomobject]@{ Mode = 'Generic'; Schemes = @() }
        }
        $security = foreach ($name in $schemeNames) {
            @{ $name = @() }
        }
    }
    $requirements = @($security)
    if ($requirements.Count -eq 0) {
        return [pscustomobject]@{ Mode = 'None'; Schemes = @() }
    }
    foreach ($requirement in $requirements) {
        $entries = @(ConvertTo-OpenApiPropertyList -InputObject $requirement)
        if ($entries.Count -eq 0) {
            # An empty requirement ({}) makes authentication optional
            return [pscustomobject]@{ Mode = 'None'; Schemes = @() }
        }
        $selected = New-Object System.Collections.Generic.List[object]
        $satisfied = $true
        foreach ($entry in $entries) {
            $scheme = Get-OpenApiMember -InputObject $schemes -Name $entry.Name
            if (-not (Test-OpenApiSchemeCredential -Scheme $scheme -Context $Context)) {
                $satisfied = $false
                break
            }
            $selected.Add([pscustomobject]@{
                    Name   = $entry.Name
                    Scheme = $scheme
                    Scopes = @($entry.Value | Where-Object -FilterScript { $null -ne $_ } | ForEach-Object -Process { [string]$_ })
                })
        }
        if ($satisfied) {
            return [pscustomobject]@{ Mode = 'Selected'; Schemes = $selected.ToArray() }
        }
    }
    return [pscustomobject]@{ Mode = 'Unsatisfied'; Schemes = @() }
}
