function ConvertTo-OpenApiRequestBody {
    <#
    .SYNOPSIS
        Normalises a resolved raw request body into { Required, Description, Content }, with OA050/OA051 findings.
    .DESCRIPTION
        OA050 (Information): the preferred JSON schema is a oneOf/anyOf, so it is passed through as -Body only.
        OA051 (Warning): a media type the runtime cannot serialise (see Test-OpenApiMediaTypeSupport).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Node,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    $contentPointer = Join-OpenApiJsonPointer -Pointer $Pointer -Segment 'content'
    $content = ConvertTo-OpenApiMediaTypeList -Context $Context -Content $Node['content'] -Pointer $contentPointer

    foreach ($media in $content) {
        if (-not (Test-OpenApiMediaTypeSupport -ContentType $media.ContentType -Schema $media.Schema)) {
            Add-OpenApiFinding -Context $Context -Severity Warning -Code 'OA051' -Pointer (Join-OpenApiJsonPointer -Pointer $contentPointer -Segment $media.ContentType) -Message "Request media type '$($media.ContentType)' is not supported by the runtime serialiser; the body is sent as a raw string or bytes."
        }
    }
    if ($content.Count -gt 0) {
        $preferred = $content[0]
        if ($null -ne $preferred.Schema -and ($preferred.Schema.OneOf -or $preferred.Schema.AnyOf)) {
            Add-OpenApiFinding -Context $Context -Severity Information -Code 'OA050' -Pointer (Join-OpenApiJsonPointer -Pointer $contentPointer -Segment $preferred.ContentType, 'schema') -Message 'The request body is a oneOf/anyOf schema; it is passed through as -Body only.'
        }
    }

    $description = $null
    if ($null -ne $Node['description']) {
        $description = [string]$Node['description']
    }
    [pscustomobject]@{
        PSTypeName  = 'Tcs.OpenApi.RequestBody'
        Required    = $Node['required'] -eq $true
        Description = $description
        Content     = $content
    }
}
