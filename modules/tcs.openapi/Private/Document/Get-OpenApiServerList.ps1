function Get-OpenApiServerList {
    <#
    .SYNOPSIS
        Normalises a raw 'servers' list into [ { Url, Description, Variables } ].
    .DESCRIPTION
        No servers gives one server with Url '/' (the specification default). Relative URLs without
        variables are resolved against BaseUri (the URL the document was downloaded from) when given.
        Variables maps names to { Default, Enum, Description }.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Servers,

        [AllowNull()]
        [uri]$BaseUri
    )

    $raw = @()
    if ($Servers -is [System.Collections.IList]) {
        $raw = @($Servers | Where-Object { $_ -is [System.Collections.IDictionary] -and $null -ne $_['url'] })
    }
    if ($raw.Count -eq 0) {
        $default = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $default['url'] = '/'
        $raw = @($default)
    }

    $list = [System.Collections.Generic.List[object]]::new()
    foreach ($server in $raw) {
        $url = [string]$server['url']
        if ($null -ne $BaseUri -and $BaseUri.IsAbsoluteUri -and $url -notmatch '^[A-Za-z][A-Za-z0-9+.-]*:' -and $url -notmatch '\{') {
            $url = (New-Object -TypeName System.Uri -ArgumentList $BaseUri, $url).AbsoluteUri
        }
        $variables = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        if ($server['variables'] -is [System.Collections.IDictionary]) {
            foreach ($name in @($server['variables'].Keys)) {
                $variable = $server['variables'][$name]
                if ($variable -isnot [System.Collections.IDictionary]) {
                    continue
                }
                $enum = $null
                if ($variable['enum'] -is [System.Collections.IList]) {
                    $enum = [object[]]$variable['enum']
                }
                $variables[$name] = [pscustomobject]@{
                    Default     = $variable['default']
                    Enum        = $enum
                    Description = $variable['description']
                }
            }
        }
        $list.Add([pscustomobject]@{
                PSTypeName  = 'Tcs.OpenApi.Server'
                Url         = $url
                Description = $server['description']
                Variables   = $variables
            })
    }
    return , $list.ToArray()
}
