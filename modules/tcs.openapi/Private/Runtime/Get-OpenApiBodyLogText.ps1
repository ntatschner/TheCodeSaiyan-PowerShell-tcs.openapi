function Get-OpenApiBodyLogText {
    <#
    .SYNOPSIS
        Returns request body text for Debug output with secrets redacted; binary and multipart bodies are summarised by size.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Net.Http.HttpContent]$Content
    )

    $contentType = $null
    if ($null -ne $Content.Headers.ContentType) {
        $contentType = $Content.Headers.ContentType.MediaType
    }
    $kind = Get-OpenApiMediaTypeKind -ContentType $contentType
    if ($Content -is [System.Net.Http.ByteArrayContent] -and $Content -isnot [System.Net.Http.MultipartContent] -and ($kind -eq 'Json' -or $kind -eq 'Form' -or $kind -eq 'Text')) {
        $text = $Content.ReadAsStringAsync().GetAwaiter().GetResult()
        return (Get-OpenApiRedactedText -Text $text)
    }
    $length = $Content.Headers.ContentLength
    if ($null -eq $length) {
        return "[$contentType content]"
    }
    return "[$contentType content, $length bytes]"
}
