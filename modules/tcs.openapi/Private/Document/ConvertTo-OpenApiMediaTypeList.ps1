function ConvertTo-OpenApiMediaTypeList {
    <#
    .SYNOPSIS
        Normalises a raw 'content' map into MediaType objects { ContentType, Schema, Encoding }, JSON types first.
    .DESCRIPTION
        Order: application/json (with or without parameters), then other JSON types (*/*+json, */json),
        then the rest; document order within each group. Encoding becomes a map of property name to
        { ContentType, Style, Explode, AllowReserved }, or $null.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Content,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    $groups = @(
        [System.Collections.Generic.List[object]]::new(),
        [System.Collections.Generic.List[object]]::new(),
        [System.Collections.Generic.List[object]]::new()
    )
    if ($Content -is [System.Collections.IDictionary]) {
        foreach ($contentType in @($Content.Keys)) {
            $media = $Content[$contentType]
            $mediaPointer = Join-OpenApiJsonPointer -Pointer $Pointer -Segment $contentType
            $schema = $null
            $encoding = $null
            if ($media -is [System.Collections.IDictionary]) {
                if ($media.Contains('schema')) {
                    $schema = ConvertTo-OpenApiSchema -Context $Context -Node $media['schema'] -Pointer (Join-OpenApiJsonPointer -Pointer $mediaPointer -Segment 'schema')
                }
                if ($media['encoding'] -is [System.Collections.IDictionary]) {
                    $encoding = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
                    foreach ($property in @($media['encoding'].Keys)) {
                        $raw = $media['encoding'][$property]
                        if ($raw -isnot [System.Collections.IDictionary]) {
                            continue
                        }
                        $explode = $null
                        if ($raw.Contains('explode')) {
                            $explode = $raw['explode'] -eq $true
                        }
                        $encoding[$property] = [pscustomobject]@{
                            ContentType   = $raw['contentType']
                            Style         = $raw['style']
                            Explode       = $explode
                            AllowReserved = $raw['allowReserved'] -eq $true
                        }
                    }
                }
            }
            $item = [pscustomobject]@{
                PSTypeName  = 'Tcs.OpenApi.MediaType'
                ContentType = $contentType
                Schema      = $schema
                Encoding    = $encoding
            }
            $mediaType = $contentType.Split(';')[0].Trim().ToLowerInvariant()
            if ($mediaType -eq 'application/json') {
                $groups[0].Add($item)
            }
            elseif ($mediaType -match '^[^/]+/([^/]+\+)?json$') {
                $groups[1].Add($item)
            }
            else {
                $groups[2].Add($item)
            }
        }
    }
    $all = [System.Collections.Generic.List[object]]::new()
    foreach ($group in $groups) {
        $all.AddRange($group)
    }
    return , $all.ToArray()
}
