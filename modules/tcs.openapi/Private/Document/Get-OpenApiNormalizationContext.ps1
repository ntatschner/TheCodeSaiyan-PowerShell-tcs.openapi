function Get-OpenApiNormalizationContext {
    <#
    .SYNOPSIS
        Creates the state object that is passed through one normalisation run (findings, schema cache, visited set).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Root,

        [AllowNull()]
        [string]$SourceVersion
    )

    [pscustomobject]@{
        PSTypeName       = 'Tcs.OpenApi.NormalizationContext'
        Root             = $Root
        SourceVersion    = $SourceVersion
        Findings         = New-Object -TypeName System.Collections.Generic.List[object]
        FindingKeys      = New-Object -TypeName System.Collections.Generic.HashSet[string] -ArgumentList ([System.StringComparer]::Ordinal)
        SchemaCache      = New-Object -TypeName 'System.Collections.Generic.Dictionary[string,object]' -ArgumentList ([System.StringComparer]::Ordinal)
        TaintedSchemas   = New-Object -TypeName System.Collections.Generic.HashSet[string] -ArgumentList ([System.StringComparer]::Ordinal)
        SchemaStack      = New-Object -TypeName System.Collections.Generic.HashSet[string] -ArgumentList ([System.StringComparer]::Ordinal)
        ExternalRefHits  = 0
        CurrentOperation = $null
    }
}
