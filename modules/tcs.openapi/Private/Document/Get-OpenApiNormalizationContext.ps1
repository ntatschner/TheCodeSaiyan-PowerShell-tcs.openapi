function Get-OpenApiNormalizationContext {
    <#
    .SYNOPSIS
        Creates the state object that is passed through one normalisation run (findings, schema and stub caches, visited set).
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
        Findings         = [System.Collections.Generic.List[object]]::new()
        FindingKeys      = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        SchemaCache      = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        StubCache        = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
        TaintedSchemas   = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        SchemaStack      = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        ExternalRefHits  = 0
        CurrentOperation = $null
    }
}
