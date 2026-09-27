function New-OpenApiRequestUri {
    <#
    .SYNOPSIS
        Builds the request URL from the base URI, the path template, and the path and query parameter values.
    .DESCRIPTION
        Path values are escaped as one segment, except for a scalar value of a CatchAll or AllowReserved path
        parameter with the simple style: it keeps its '/' (leading and trailing ones are trimmed) and each
        segment is escaped on its own.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory object only; it changes no state.')]
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$BaseUri,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path,

        [Parameter()]
        [AllowNull()]
        [object[]]$Parameter,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$PathParameters,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$QueryParameters
    )

    $lookup = @{}
    if ($null -ne $PathParameters) {
        foreach ($key in $PathParameters.Keys) {
            $lookup[[string]$key] = $PathParameters[$key]
        }
    }

    foreach ($placeholder in [regex]::Matches($Path, '\{([^}]+)\}')) {
        $name = $placeholder.Groups[1].Value
        if (-not $lookup.ContainsKey($name) -or $null -eq $lookup[$name]) {
            throw (New-Object System.ArgumentException -ArgumentList "The path parameter '$name' is required but was not given.", $name)
        }
    }

    $expanded = [regex]::Replace($Path, '\{([^}]+)\}', {
            param($match)
            $name = $match.Groups[1].Value
            $style = Get-OpenApiParameterStyle -Parameter $Parameter -Name $name -In 'path'
            $pathStyle = $style.Style
            if ($pathStyle -ne 'label' -and $pathStyle -ne 'matrix') {
                $pathStyle = 'simple'
            }
            $value = $lookup[$name]
            if (($style.CatchAll -or $style.AllowReserved) -and $pathStyle -eq 'simple' -and (Get-OpenApiValueShape -Value $value) -eq 'Scalar') {
                # A catch-all segment ('/consoles/{id}/*path') holds a path of its own
                $segments = (ConvertTo-OpenApiScalarString -Value $value).Trim('/').Split('/')
                return ((@($segments | ForEach-Object -Process { ConvertTo-OpenApiUriEncoded -Value $_ })) -join '/')
            }
            return (ConvertTo-OpenApiPathParameter -Name $name -Value $lookup[$name] -Style $pathStyle -Explode:$style.Explode)
        })

    $uri = $BaseUri.TrimEnd('/')
    if ($expanded.Length -gt 0) {
        if (-not $expanded.StartsWith('/')) {
            $uri += '/'
        }
        $uri += $expanded
    }

    $pairs = New-Object System.Collections.Generic.List[string]
    if ($null -ne $QueryParameters) {
        foreach ($key in $QueryParameters.Keys) {
            $style = Get-OpenApiParameterStyle -Parameter $Parameter -Name ([string]$key) -In 'query'
            $queryStyle = $style.Style
            if (@('form', 'spaceDelimited', 'pipeDelimited', 'deepObject') -notcontains $queryStyle) {
                $queryStyle = 'form'
            }
            foreach ($pair in (ConvertTo-OpenApiQueryParameter -Name ([string]$key) -Value $QueryParameters[$key] -Style $queryStyle -Explode:$style.Explode -AllowReserved:$style.AllowReserved)) {
                $pairs.Add($pair)
            }
        }
    }
    return (Add-OpenApiQueryString -Uri $uri -Pair $pairs.ToArray())
}
