function ConvertTo-OpenApiResponseText {
    <#
    .SYNOPSIS
        Decodes response bytes as text using the charset of the content type (UTF-8 by default, BOM removed).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [byte[]]$Bytes,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ContentType
    )

    if ($null -eq $Bytes -or $Bytes.Length -eq 0) {
        return ''
    }
    $encoding = New-Object System.Text.UTF8Encoding -ArgumentList $false
    if (-not [string]::IsNullOrEmpty($ContentType) -and $ContentType -match 'charset\s*=\s*"?([^";\s]+)') {
        try {
            $encoding = [System.Text.Encoding]::GetEncoding($Matches[1])
        }
        catch {
            Write-Verbose -Message "Unknown charset '$($Matches[1])'; the response is read as UTF-8."
        }
    }
    $text = $encoding.GetString($Bytes)
    if ($text.Length -gt 0 -and $text[0] -eq [char]0xFEFF) {
        $text = $text.Substring(1)
    }
    return $text
}
