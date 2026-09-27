function ConvertTo-OpenApiResponseList {
    <#
    .SYNOPSIS
        Normalises a raw 'responses' map into [ { StatusCode, Description, Content, Headers } ] in document order.
    .DESCRIPTION
        Response and header $refs are resolved. Range codes are upper-cased ('2xx' -> '2XX'). Headers is a
        map of header name to { Description, Required, Deprecated, Schema }.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Responses,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer
    )

    $list = New-Object -TypeName System.Collections.Generic.List[object]
    if ($Responses -isnot [System.Collections.IDictionary]) {
        return , $list.ToArray()
    }
    foreach ($code in @($Responses.Keys)) {
        $resolved = Resolve-OpenApiComponentReference -Context $Context -Node $Responses[$code] -Pointer (Join-OpenApiJsonPointer -Pointer $Pointer -Segment $code)
        if ($null -eq $resolved -or $resolved.Node -isnot [System.Collections.IDictionary]) {
            continue
        }
        $response = $resolved.Node
        $statusCode = [string]$code
        if ($statusCode -match '^[1-5]xx$') {
            $statusCode = $statusCode.ToUpperInvariant()
        }

        $headers = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        if ($response['headers'] -is [System.Collections.IDictionary]) {
            foreach ($name in @($response['headers'].Keys)) {
                $header = Resolve-OpenApiComponentReference -Context $Context -Node $response['headers'][$name] -Pointer (Join-OpenApiJsonPointer -Pointer $resolved.Pointer -Segment 'headers', $name)
                if ($null -eq $header -or $header.Node -isnot [System.Collections.IDictionary]) {
                    continue
                }
                $headerSchema = $null
                if ($header.Node.Contains('schema')) {
                    $headerSchema = ConvertTo-OpenApiSchema -Context $Context -Node $header.Node['schema'] -Pointer (Join-OpenApiJsonPointer -Pointer $header.Pointer -Segment 'schema')
                }
                elseif ($header.Node['content'] -is [System.Collections.IDictionary]) {
                    $headerContent = ConvertTo-OpenApiMediaTypeList -Context $Context -Content $header.Node['content'] -Pointer (Join-OpenApiJsonPointer -Pointer $header.Pointer -Segment 'content')
                    if ($headerContent.Count -gt 0) {
                        $headerSchema = $headerContent[0].Schema
                    }
                }
                $headerDescription = $null
                if ($null -ne $header.Node['description']) {
                    $headerDescription = [string]$header.Node['description']
                }
                $headers[$name] = [pscustomobject]@{
                    Description = $headerDescription
                    Required    = $header.Node['required'] -eq $true
                    Deprecated  = $header.Node['deprecated'] -eq $true
                    Schema      = $headerSchema
                }
            }
        }

        $description = $null
        if ($null -ne $response['description']) {
            $description = [string]$response['description']
        }
        $list.Add([pscustomobject]@{
                PSTypeName  = 'Tcs.OpenApi.Response'
                StatusCode  = $statusCode
                Description = $description
                Content     = ConvertTo-OpenApiMediaTypeList -Context $Context -Content $response['content'] -Pointer (Join-OpenApiJsonPointer -Pointer $resolved.Pointer -Segment 'content')
                Headers     = $headers
            })
    }
    return , $list.ToArray()
}
