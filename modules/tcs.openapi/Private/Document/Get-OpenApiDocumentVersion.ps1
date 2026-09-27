function Get-OpenApiDocumentVersion {
    <#
    .SYNOPSIS
        Detects the document version. Returns { SourceVersion, Family ('2.0'|'3.0'|'3.1'), Supported, Pointer, Message }.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Root
    )

    $result = [pscustomobject]@{ SourceVersion = $null; Family = $null; Supported = $false; Pointer = ''; Message = $null }
    if ($Root -isnot [System.Collections.IDictionary]) {
        $result.Message = 'The document is not a JSON/YAML object, so it is not an OpenAPI or Swagger document.'
        return $result
    }
    if ($Root.Contains('openapi')) {
        $value = [string]$Root['openapi']
        $result.SourceVersion = $value
        $result.Pointer = '/openapi'
        if ($value -match '^3\.0\.\d+$') {
            $result.Family = '3.0'
            $result.Supported = $true
        }
        elseif ($value -match '^3\.1\.\d+$') {
            $result.Family = '3.1'
            $result.Supported = $true
        }
        else {
            $result.Message = "OpenAPI version '$value' is not supported; supported versions are 3.0.x, 3.1.x and Swagger 2.0."
        }
        return $result
    }
    if ($Root.Contains('swagger')) {
        $value = [string]$Root['swagger']
        $result.Pointer = '/swagger'
        if ($value -eq '2.0' -or $value -eq '2') {
            $result.SourceVersion = '2.0'
            $result.Family = '2.0'
            $result.Supported = $true
        }
        else {
            $result.SourceVersion = $value
            $result.Message = "Swagger version '$value' is not supported; supported versions are 3.0.x, 3.1.x and Swagger 2.0."
        }
        return $result
    }
    $result.Message = "The document has neither an 'openapi' nor a 'swagger' version field."
    return $result
}
