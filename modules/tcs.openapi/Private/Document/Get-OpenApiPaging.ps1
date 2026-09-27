function Get-OpenApiPaging {
    <#
    .SYNOPSIS
        Works out how an operation pages: { Kind ('nextLink'|'linkHeader'), ItemsProperty, NextLinkProperty },
        { Kind 'token', ItemsProperty, TokenParameter, TokenProperty } or $null.
    .DESCRIPTION
        1. x-ms-pageable: nextLinkName (null means one page only, so no paging) and itemName (default 'value').
        2. The first 2xx JSON response (200 first) is an object with exactly one array property and a string
           property named nextLink, next or @odata.nextLink (any case) -> 'nextLink'.
        3. The operation has a query parameter named nextToken, pageToken, next_token, page_token, cursor,
           continuationToken or continuation_token (any case) and that first 2xx JSON response is an object
           with exactly one array property and a string property named like the parameter, or nextToken,
           nextPageToken, next_page_token, next_token, next_cursor or nextCursor (any case) -> 'token'.
        4. A 2xx response declares a 'Link' header -> 'linkHeader' (ItemsProperty is the single array
           property of an object body, or $null when the body is the array).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Operation,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Responses,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$Parameters
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
    $tokenParameterNames = @('nextToken', 'pageToken', 'next_token', 'page_token', 'cursor', 'continuationToken', 'continuation_token')
    $tokenPropertyNames = @('nextToken', 'nextPageToken', 'next_page_token', 'next_token', 'next_cursor', 'nextCursor')
    $tokenParameter = $null
    foreach ($parameter in @($Parameters)) {
        if ($null -ne $parameter -and $parameter.In -eq 'query' -and $tokenParameterNames -contains $parameter.Name) {
            $tokenParameter = [string]$parameter.Name
            break
        }
    }
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
        $tokenProperty = $null
        $tokenRank = [int]::MaxValue
        foreach ($name in $schema.Properties.Keys) {
            $property = $schema.Properties[$name]
            if ($null -eq $property) {
                continue
            }
            $isString = ($property.Type -eq 'string' -or $null -eq $property.Type)
            if ($property.Type -eq 'array') {
                $arrays.Add($name)
            }
            elseif ($null -eq $link -and $nextLinkNames -contains $name -and $isString) {
                $link = $name
            }
            elseif ($null -ne $tokenParameter -and $isString) {
                # The property named like the parameter first, then the usual names in list order
                $rank = [int]::MaxValue
                if ($name -eq $tokenParameter) {
                    $rank = -1
                }
                elseif ($tokenPropertyNames -contains $name) {
                    $rank = [array]::IndexOf(@($tokenPropertyNames | ForEach-Object -Process { $_.ToLowerInvariant() }), $name.ToLowerInvariant())
                }
                if ($rank -lt $tokenRank) {
                    $tokenRank = $rank
                    $tokenProperty = $name
                }
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
            if ($null -ne $tokenProperty) {
                return [pscustomobject]@{
                    PSTypeName     = 'Tcs.OpenApi.Paging'
                    Kind           = 'token'
                    ItemsProperty  = $arrayProperty
                    TokenParameter = $tokenParameter
                    TokenProperty  = $tokenProperty
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
