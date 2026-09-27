function Build-OpenApiHttpContent {
    <#
    .SYNOPSIS
        Creates the System.Net.Http.HttpContent for a request body according to its content type (JSON, form, multipart, text or binary).
    #>
    [CmdletBinding()]
    [OutputType([System.Net.Http.HttpContent])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Body,

        [Parameter(Mandatory)]
        [string]$ContentType
    )

    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $kind = Get-OpenApiMediaTypeKind -ContentType $ContentType
    $mediaType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($ContentType)

    switch ($kind) {
        'Json' {
            if ($Body -is [string]) {
                # A string is taken to be JSON text already
                $text = $Body
            }
            else {
                $text = ConvertTo-OpenApiJsonText -InputObject $Body
            }
            $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $utf8.GetBytes($text))
            if ([string]::IsNullOrEmpty($mediaType.CharSet)) {
                $mediaType.CharSet = 'utf-8'
            }
            $content.Headers.ContentType = $mediaType
            return $content
        }
        'Form' {
            $text = ConvertTo-OpenApiFormBody -InputObject $Body
            $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $utf8.GetBytes($text))
            $content.Headers.ContentType = $mediaType
            return $content
        }
        'Multipart' {
            $multipart = Build-OpenApiMultipartContent -Body $Body -MediaType $mediaType
            return , $multipart
        }
        'Text' {
            $text = ConvertTo-OpenApiScalarString -Value $Body
            if ($Body -is [byte[]]) {
                $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $Body)
            }
            else {
                $content = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $utf8.GetBytes($text))
                if ([string]::IsNullOrEmpty($mediaType.CharSet)) {
                    $mediaType.CharSet = 'utf-8'
                }
            }
            $content.Headers.ContentType = $mediaType
            return $content
        }
        default {
            $content = Build-OpenApiBinaryContent -Value $Body -KeepStreamOpen
            $content.Headers.ContentType = $mediaType
            return $content
        }
    }
}
