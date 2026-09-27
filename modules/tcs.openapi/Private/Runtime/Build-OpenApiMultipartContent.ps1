function Build-OpenApiMultipartContent {
    <#
    .SYNOPSIS
        Creates MultipartFormDataContent from a hashtable: FileInfo, byte[] and stream values become file parts, objects JSON parts, others text parts.
    #>
    [CmdletBinding()]
    [OutputType([System.Net.Http.MultipartFormDataContent])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Body,

        [Parameter()]
        [AllowNull()]
        [System.Net.Http.Headers.MediaTypeHeaderValue]$MediaType
    )

    $boundary = $null
    if ($null -ne $MediaType) {
        foreach ($parameter in $MediaType.Parameters) {
            if ($parameter.Name -eq 'boundary') {
                $boundary = $parameter.Value.Trim('"')
            }
        }
    }
    if ([string]::IsNullOrEmpty($boundary)) {
        $boundary = '----tcs-openapi-' + [guid]::NewGuid().ToString('N')
    }
    $multipart = New-Object System.Net.Http.MultipartFormDataContent -ArgumentList $boundary
    if ($null -eq $Body) {
        return , $multipart
    }
    if ($Body -isnot [System.Collections.IDictionary] -and $Body -isnot [System.Management.Automation.PSCustomObject]) {
        throw (New-Object System.ArgumentException -ArgumentList 'A multipart/form-data body must be a hashtable of part names and values.')
    }
    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    foreach ($property in (ConvertTo-OpenApiPropertyList -InputObject $Body)) {
        $values = @($property.Value)
        if ($property.Value -is [byte[]] -or $property.Value -is [System.Collections.IDictionary] -or $property.Value -is [System.Management.Automation.PSCustomObject]) {
            $values = @(, $property.Value)
        }
        foreach ($value in $values) {
            if ($value -is [System.Management.Automation.PSObject]) {
                $value = $value.PSObject.BaseObject
            }
            if ($value -is [System.IO.FileInfo]) {
                $part = Build-OpenApiBinaryContent -Value $value
                $part.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/octet-stream')
                $multipart.Add($part, $property.Name, $value.Name)
            }
            elseif ($value -is [byte[]] -or $value -is [System.IO.Stream]) {
                $part = Build-OpenApiBinaryContent -Value $value
                $part.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/octet-stream')
                $multipart.Add($part, $property.Name, $property.Name)
            }
            elseif ($value -is [System.Collections.IDictionary] -or $value -is [System.Management.Automation.PSCustomObject]) {
                $part = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $utf8.GetBytes((ConvertTo-OpenApiJsonText -InputObject $value)))
                $part.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/json; charset=utf-8')
                $multipart.Add($part, $property.Name)
            }
            else {
                $part = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $utf8.GetBytes((ConvertTo-OpenApiScalarString -Value $value)))
                $part.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('text/plain; charset=utf-8')
                $multipart.Add($part, $property.Name)
            }
        }
    }
    return , $multipart
}
