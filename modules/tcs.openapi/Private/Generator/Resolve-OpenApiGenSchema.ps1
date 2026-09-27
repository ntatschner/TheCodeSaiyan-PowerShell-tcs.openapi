function Resolve-OpenApiGenSchema {
    <#
    .SYNOPSIS
        Returns the full named schema for a schema stub, or the schema itself.

    .DESCRIPTION
        Inside named schemas the document model keeps nested $refs as stubs: RefName plus scalar
        keywords (Type, Format, Enum, bounds ...) but no Properties, AllOf, OneOf or AnyOf. When the
        generator needs the properties or the composition of such a stub, this looks the schema up in
        Document.Schemas by RefName. A schema that is not a stub, or whose name is unknown, is returned
        as it is.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Schema,

        [Parameter()]
        [AllowNull()]
        [object]$Schemas
    )

    if ($null -eq $Schema -or $null -eq $Schemas -or [string]::IsNullOrEmpty([string]$Schema.RefName)) {
        return $Schema
    }
    $hasStructure = (@(Get-OpenApiGenMapEntry -Map $Schema.Properties).Count -gt 0) -or
    (@(@($Schema.AllOf) + @($Schema.OneOf) + @($Schema.AnyOf) | Where-Object -FilterScript { $null -ne $_ }).Count -gt 0)
    if ($hasStructure) {
        return $Schema
    }
    $named = Get-OpenApiGenMapValue -Map $Schemas -Key ([string]$Schema.RefName)
    if ($null -eq $named) {
        return $Schema
    }
    return $named
}
