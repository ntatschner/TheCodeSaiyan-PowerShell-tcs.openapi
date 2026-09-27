function ConvertFrom-OpenApiErrorBody {
    <#
    .SYNOPSIS
        Parses an error response body: JSON (including application/problem+json) becomes an object, other text is returned as it is.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ContentType
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }
    $trimmed = $Text.TrimStart()
    $looksJson = (Get-OpenApiMediaTypeKind -ContentType $ContentType) -eq 'Json' -or $trimmed.StartsWith('{') -or $trimmed.StartsWith('[')
    if ($looksJson) {
        try {
            return (ConvertFrom-OpenApiResponseJson -Text $Text)
        }
        catch {
            Write-Verbose -Message "The error response body is not valid JSON: $($_.Exception.Message)"
        }
    }
    return $Text
}
