function Get-OpenApiDocumentText {
    <#
    .SYNOPSIS
        Reads document text from a file, a URL or a string. Returns { Text, Source, BaseUri, Format }.
    .DESCRIPTION
        Files are read with BOM detection (UTF-8 default). URLs are downloaded with Invoke-WebRequest and
        decoded as UTF-8 from the raw bytes, so Windows PowerShell 5.1 does not fall back to ISO-8859-1.
        Format is 'Json' for .json files and 'Auto' (detected from the content) otherwise, so a .yaml file
        that holds JSON does not need powershell-yaml.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Path')]
        [string]$Path,

        [Parameter(Mandatory, ParameterSetName = 'Uri')]
        [uri]$Uri,

        [Parameter(Mandatory, ParameterSetName = 'InputObject')]
        [AllowEmptyString()]
        [string]$InputObject
    )

    switch ($PSCmdlet.ParameterSetName) {
        'Path' {
            $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop | Select-Object -First 1
            $fullPath = $resolved.ProviderPath
            if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                throw "The path '$Path' is not a file."
            }
            $format = 'Auto'
            if ([System.IO.Path]::GetExtension($fullPath) -eq '.json') {
                $format = 'Json'
            }
            $text = [System.IO.File]::ReadAllText($fullPath, [System.Text.Encoding]::UTF8)
            return [pscustomobject]@{ Text = $text; Source = $fullPath; BaseUri = $null; Format = $format }
        }
        'Uri' {
            if (-not $Uri.IsAbsoluteUri) {
                throw "The URI '$Uri' must be absolute."
            }
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -Headers @{ Accept = 'application/json, application/yaml;q=0.9, */*;q=0.8' } -ErrorAction Stop
            $bytes = $null
            if ($null -ne $response.RawContentStream) {
                $bytes = $response.RawContentStream.ToArray()
            }
            elseif ($response.Content -is [byte[]]) {
                $bytes = $response.Content
            }
            if ($null -ne $bytes) {
                $offset = 0
                if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                    $offset = 3
                }
                $text = [System.Text.Encoding]::UTF8.GetString($bytes, $offset, $bytes.Length - $offset)
            }
            else {
                $text = [string]$response.Content
            }
            return [pscustomobject]@{ Text = $text; Source = $Uri.AbsoluteUri; BaseUri = $Uri; Format = 'Auto' }
        }
        'InputObject' {
            return [pscustomobject]@{ Text = $InputObject; Source = 'InputObject'; BaseUri = $null; Format = 'Auto' }
        }
    }
}
