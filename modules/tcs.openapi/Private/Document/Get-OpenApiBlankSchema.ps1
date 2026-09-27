function Get-OpenApiBlankSchema {
    <#
    .SYNOPSIS
        Returns a normalised schema object with every property at its default (a schema that accepts anything).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    [pscustomobject]@{
        PSTypeName           = 'Tcs.OpenApi.Schema'
        Type                 = $null
        Format               = $null
        Nullable             = $false
        Enum                 = $null
        Default              = $null
        Const                = $null
        Items                = $null
        Properties           = $null
        Required             = @()
        AdditionalProperties = $null
        AllOf                = $null
        OneOf                = $null
        AnyOf                = $null
        Discriminator        = $null
        ReadOnly             = $false
        WriteOnly            = $false
        Description          = $null
        RefName              = $null
        Recursive            = $false
        Title                = $null
        Pattern              = $null
        Minimum              = $null
        Maximum              = $null
        ExclusiveMinimum     = $null
        ExclusiveMaximum     = $null
        MinLength            = $null
        MaxLength            = $null
        MinItems             = $null
        MaxItems             = $null
        Example              = $null
        Deprecated           = $false
    }
}
