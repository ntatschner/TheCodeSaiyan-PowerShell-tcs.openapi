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

    $success = @($Responses | Where-Object { $_.StatusCode -eq '200' }) + @($Responses | Where-Object { $_.StatusCode -match '^2' -and $_.StatusCode -ne '200' })
    $arrayProperty = $null
    $bodyIsArray = $false
    foreach ($response in $success) {
        $json = @($response.Content | Where-Object { $_.ContentType -match '^[^/]+/([^/;]+\+)?json\s*(;|$)' -or $_.ContentType -eq '*/*' }) | Select-Object -First 1
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
        $arrays = @($schema.Properties.Keys | Where-Object { $null -ne $schema.Properties[$_] -and $schema.Properties[$_].Type -eq 'array' })
        $links = @($schema.Properties.Keys | Where-Object {
                @('nextLink', 'next', '@odata.nextLink') -contains $_ -and $null -ne $schema.Properties[$_] -and ($schema.Properties[$_].Type -eq 'string' -or $null -eq $schema.Properties[$_].Type)
            })
        if ($arrays.Count -eq 1) {
            $arrayProperty = $arrays[0]
            if ($links.Count -ge 1) {
                return [pscustomobject]@{
                    PSTypeName       = 'Tcs.OpenApi.Paging'
                    Kind             = 'nextLink'
                    ItemsProperty    = $arrayProperty
                    NextLinkProperty = $links[0]
                }
            }
        }
        break
    }

    foreach ($response in $success) {
        if ($null -ne $response.Headers -and @($response.Headers.Keys | Where-Object { $_ -eq 'Link' }).Count -gt 0) {
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
    return $null
}
