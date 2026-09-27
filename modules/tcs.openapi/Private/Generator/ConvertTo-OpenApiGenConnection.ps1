function ConvertTo-OpenApiGenConnection {
    <#
    .SYNOPSIS
        Renders the Set-, Get- and Remove-<Prefix>Context commands of a generated module.

    .DESCRIPTION
        They call Set-/Get-/Remove-OpenApiContext with -Service fixed to the module's service. -BaseUri
        of Set-<Prefix>Context defaults to the first absolute http(s) server URL of the document (server
        variables replaced by their defaults); without one it is mandatory. The example (and the README's
        'Getting started') passes -BaseUri only when it is mandatory, plus -AuthExample (see
        Get-OpenApiGenAuthExample).
        Returns one { Name, RelativePath, ConnectExample, Text } per command (ConnectExample is the
        parameter text of the example, for the README).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Prefix,

        [Parameter(Mandatory = $true)]
        [string]$Service,

        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Server,

        [Parameter()]
        [AllowEmptyString()]
        [string]$AuthExample = " -BearerToken (Read-Host -AsSecureString -Prompt 'Token')",

        [Parameter(Mandatory = $true)]
        [hashtable]$Template
    )

    $baseUri = $null
    foreach ($entry in @($Server | Where-Object -FilterScript { $null -ne $_ })) {
        $url = [string]$entry.Url
        foreach ($variable in @(Get-OpenApiGenMapEntry -Map $entry.Variables)) {
            $default = Get-OpenApiGenMapValue -Map $variable.Value -Key 'Default'
            if ($null -ne $default) {
                $url = $url.Replace('{' + $variable.Key + '}', [string]$default)
            }
        }
        if ($url -match '^https?://[^{}\s]+$') {
            $baseUri = $url
            break
        }
    }

    if ($null -ne $baseUri) {
        $baseUriParameter = @(
            '        [Parameter()]'
            '        [string]'
            '        $BaseUri = ' + (ConvertTo-OpenApiGenLiteral -Value $baseUri) + ','
        ) -join "`n"
        $baseUriHelp = "Defaults to $baseUri."
        $connectExample = $AuthExample
    }
    else {
        $baseUriParameter = @(
            '        [Parameter(Mandatory = $true)]'
            '        [string]'
            '        $BaseUri,'
        ) -join "`n"
        $baseUriHelp = 'The document does not name an absolute server URL, so this is required.'
        $connectExample = ' -BaseUri ''https://api.example.com''' + $AuthExample
    }

    $values = @{
        Prefix           = $Prefix
        Service          = $Service
        ModuleName       = $ModuleName
        BaseUriParameter = $baseUriParameter
        BaseUriHelp      = $baseUriHelp
        ConnectExample   = $connectExample
    }
    foreach ($verb in @('Set', 'Get', 'Remove')) {
        $name = "$verb-$($Prefix)Context"
        [pscustomobject]@{
            Name           = $name
            RelativePath   = "Public/_Connection/$name.ps1"
            ConnectExample = $connectExample
            Text           = (Expand-OpenApiGenTemplate -Template $Template["$verb-Context.ps1"] -Value $values)
        }
    }
}
