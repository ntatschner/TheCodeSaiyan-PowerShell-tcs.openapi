function ConvertTo-OpenApiSchemaStub {
    <#
    .SYNOPSIS
        Returns a reference stub of a normalised schema: a copy with its scalar keywords (Type, Format, Enum, Nullable, ...) and RefName but no nested structure.
    .DESCRIPTION
        Used for a $ref to a named component schema inside another named schema. Properties, Required,
        AdditionalProperties (when it is a schema), AllOf/OneOf/AnyOf and Discriminator are dropped; Items is
        replaced by its own stub, so array element types and enums are kept. The full schema is
        Document.Schemas[RefName]. Stubs keep the serialised model linear in size.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Schema
    )

    $stub = $Schema.PSObject.Copy()
    $stub.Properties = $null
    $stub.Required = @()
    if ($stub.AdditionalProperties -isnot [bool]) {
        $stub.AdditionalProperties = $null
    }
    $stub.AllOf = $null
    $stub.OneOf = $null
    $stub.AnyOf = $null
    $stub.Discriminator = $null
    if ($null -ne $Schema.Items) {
        $stub.Items = ConvertTo-OpenApiSchemaStub -Schema $Schema.Items
    }
    return $stub
}
