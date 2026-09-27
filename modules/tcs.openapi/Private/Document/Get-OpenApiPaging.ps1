function Get-OpenApiPaging {
    <#
    .SYNOPSIS
        Works out how an operation pages: { Kind ('nextLink'|'linkHeader'), ItemsProperty, NextLinkProperty } or $null.
    .DESCRIPTION
        1. x-ms-pageable: nextLinkName (null means one page only, so no paging) and itemName (default 'value').
        2. The first 2xx JSON response (200 first) is an object with exactly one array property and a string
           property named nextLink, next or @odata.nextLink (any case) -> 'nextLink'.
        3. A 2xx response declares a 'Link' header -> 'linkHeader' (ItemsProperty is the single array
           property of an object body, or $null when the body is the array).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Operation,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Responses
    )

    if ($Operation.Contains('x-ms-pageable')) {
        $pageable = $Operation['x-ms-pageable']
        if ($pageable -isnot [System.Collections.IDictionary] -or $null -eq $pageable['nextLinkName']) {
            return $null
        }
        $itemName = 'value'
        if ($null -ne $pageable['itemName']) {
            $itemName = [string]$pageable['itemName']
        }
        return [pscustomobject]@{
            PSTypeName       = 'Tcs.OpenApi.Paging'
            Kind             = 'nextLink'
            ItemsProperty    = $itemName
            NextLinkProperty = [string]$pageable['nextLinkName']
        }
    }

    # Success responses, 200 first (foreach loops rather than pipelines: this runs for every operation)
    $success = [System.Collections.Generic.List[object]]::new()
    foreach ($response in $Responses) {
        if ($response.StatusCode -eq '200') {
            $success.Insert(0, $response)
        }
        elseif ($response.StatusCode -match '^2') {
            $success.Add($response)
        }
    }
    $nextLinkNames = @('nextLink', 'next', '@odata.nextLink')
    $arrayProperty = $null
    $bodyIsArray = $false
    foreach ($response in $success) {
        $json = $null
        foreach ($media in $response.Content) {
            if ($media.ContentType -match '^[^/]+/([^/;]+\+)?json\s*(;|$)' -or $media.ContentType -eq '*/*') {
                $json = $media
                break
            }
        }
        if ($null -eq $json -or $null -eq $json.Schema) {
            continue
        }
        $schema = $json.Schema
        if ($schema.Type -eq 'array') {
            $bodyIsArray = $true
            break
        }
        if ($null -eq $schema.Properties) {
            continue
        }
        $arrays = [System.Collections.Generic.List[string]]::new()
        $link = $null
        foreach ($name in $schema.Properties.Keys) {
            $property = $schema.Properties[$name]
            if ($null -eq $property) {
                continue
            }
            if ($property.Type -eq 'array') {
                $arrays.Add($name)
            }
            elseif ($null -eq $link -and $nextLinkNames -contains $name -and ($property.Type -eq 'string' -or $null -eq $property.Type)) {
                $link = $name
            }
        }
        if ($arrays.Count -eq 1) {
            $arrayProperty = $arrays[0]
            if ($null -ne $link) {
                return [pscustomobject]@{
                    PSTypeName       = 'Tcs.OpenApi.Paging'
                    Kind             = 'nextLink'
                    ItemsProperty    = $arrayProperty
                    NextLinkProperty = $link
                }
            }
        }
        break
    }

    foreach ($response in $success) {
        if ($null -eq $response.Headers) {
            continue
        }
        foreach ($name in $response.Headers.Keys) {
            if ($name -eq 'Link') {
                $items = $null
                if (-not $bodyIsArray) {
                    $items = $arrayProperty
                }
                return [pscustomobject]@{
                    PSTypeName       = 'Tcs.OpenApi.Paging'
                    Kind             = 'linkHeader'
                    ItemsProperty    = $items
                    NextLinkProperty = $null
                }
            }
        }
    }
    return $null
}
