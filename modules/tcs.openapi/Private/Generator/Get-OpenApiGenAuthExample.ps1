function Get-OpenApiGenAuthExample {
    <#
    .SYNOPSIS
        Returns the credential parameters of the Set-<Prefix>Context example for the document's security
        schemes (' -ApiKey (...)'), or an empty string when the document has none.

    .DESCRIPTION
        The requirement shown is the first non-empty document-level requirement, else the first non-empty requirement
        of an operation (sorted by path, then method), else the first security scheme by name (ordinal).
        Each scheme of it gives: apiKey -> -ApiKey; http basic -> -Credential; http bearer, oauth2 without
        clientCredentials and openIdConnect -> -BearerToken; oauth2 clientCredentials -> -ClientId and
        -ClientSecret. Other schemes (mutualTLS, http digest ...) and undefined names add nothing.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Document
    )

    $names = New-Object -TypeName System.Collections.ArrayList
    $requirements = @($Document.Security | Where-Object -FilterScript { $null -ne $_ -and @(Get-OpenApiGenMapEntry -Map $_).Count -gt 0 })
    if ($requirements.Count -eq 0) {
        $operations = Get-OpenApiGenOrdinalSorted -InputObject @($Document.Operations | Where-Object -FilterScript { $null -ne $_ }) -Key { [string]$_.Path + [char]0 + ([string]$_.Method).ToUpperInvariant() }
        foreach ($operation in $operations) {
            $requirements = @($operation.Security | Where-Object -FilterScript { $null -ne $_ -and @(Get-OpenApiGenMapEntry -Map $_).Count -gt 0 })
            if ($requirements.Count -gt 0) {
                break
            }
        }
    }
    if ($requirements.Count -gt 0) {
        foreach ($entry in @(Get-OpenApiGenMapEntry -Map $requirements[0])) {
            [void]$names.Add([string]$entry.Key)
        }
    }
    else {
        $allNames = @(Get-OpenApiGenMapEntry -Map $Document.SecuritySchemes | ForEach-Object -Process { [string]$_.Key })
        $sorted = Get-OpenApiGenOrdinalSorted -InputObject $allNames
        if ($sorted.Count -gt 0) {
            [void]$names.Add($sorted[0])
        }
    }

    $bearer = " -BearerToken (Read-Host -AsSecureString -Prompt 'Token')"
    $parts = New-Object -TypeName System.Collections.ArrayList
    foreach ($name in $names) {
        $scheme = Get-OpenApiGenMapValue -Map $Document.SecuritySchemes -Key $name
        if ($null -eq $scheme) {
            continue
        }
        $text = ''
        switch ([string]$scheme.Type) {
            'apiKey' {
                $text = " -ApiKey (Read-Host -AsSecureString -Prompt 'API key')"
            }
            'http' {
                switch (([string]$scheme.Scheme).ToLowerInvariant()) {
                    'basic' { $text = ' -Credential (Get-Credential)' }
                    'bearer' { $text = $bearer }
                }
            }
            'oauth2' {
                $text = $bearer
                if ($null -ne (Get-OpenApiGenMapValue -Map $scheme.Flows -Key 'clientCredentials')) {
                    $text = " -ClientId '<client id>' -ClientSecret (Read-Host -AsSecureString -Prompt 'Client secret')"
                }
            }
            'openIdConnect' {
                $text = $bearer
            }
        }
        if ($text -ne '' -and -not $parts.Contains($text)) {
            [void]$parts.Add($text)
        }
    }
    return ($parts.ToArray() -join '')
}
