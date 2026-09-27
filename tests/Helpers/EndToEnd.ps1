<#
.SYNOPSIS
    Helpers for the end-to-end tests: generate a module from a fixture with the real generator and read
    what the test HTTP server recorded.

.DESCRIPTION
    Dot-source this file after importing tcs.openapi from the repository. The generated modules declare
    RequiredModules = tcs.openapi, which the already imported repository copy satisfies.
#>

function New-EndToEndModule {
    <#
    .SYNOPSIS
        Imports a fixture with Import-OpenApiDocument, generates a module with New-OpenApiModule and
        returns the generation result.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper: writes into the test drive.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Fixture,

        [Parameter(Mandatory)]
        [string]$ModuleName,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter()]
        [string]$NounPrefix
    )

    $fixturePath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ChildPath (Join-Path -Path 'Fixtures' -ChildPath $Fixture)
    $document = Import-OpenApiDocument -Path $fixturePath
    $parameters = @{
        Document   = $document
        ModuleName = $ModuleName
        OutputPath = $OutputPath
    }
    if ($NounPrefix) {
        $parameters['NounPrefix'] = $NounPrefix
    }
    return New-OpenApiModule @parameters
}

function Get-EndToEndRequest {
    <#
    .SYNOPSIS
        Returns the requests the test server recorded, optionally only those for one method and path.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Server,

        [Parameter()]
        [string]$Method,

        [Parameter()]
        [string]$Path
    )

    foreach ($request in @($Server.Requests.ToArray())) {
        if ($Method -and $request.Method -ne $Method) {
            continue
        }
        if ($Path -and $request.Path -ne $Path) {
            continue
        }
        $request
    }
}

function Get-EndToEndQueryPair {
    <#
    .SYNOPSIS
        Splits the query of a recorded request's raw URL into its 'name=value' pairs (still encoded).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [object]$Request
    )

    $rawUrl = [string]$Request.RawUrl
    $query = ''
    $index = $rawUrl.IndexOf('?')
    if ($index -ge 0) {
        $query = $rawUrl.Substring($index + 1)
    }
    return [string[]]@($query.Split('&') | Where-Object -FilterScript { $_ -ne '' })
}
