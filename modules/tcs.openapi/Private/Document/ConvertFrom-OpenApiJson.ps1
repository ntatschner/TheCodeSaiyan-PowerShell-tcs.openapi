function ConvertFrom-OpenApiJson {
    <#
    .SYNOPSIS
        Parses JSON text into the raw document tree (see ConvertTo-OpenApiRawNode).
    .DESCRIPTION
        Engines:
          SystemTextJson       System.Text.Json.JsonDocument. Keys stay case-sensitive, date-like strings stay
                               strings. The default on PowerShell 7.
          ConvertFromJson      ConvertFrom-Json. The default on Windows PowerShell 5.1. If it fails (for example
                               because two keys differ only in case) the text is parsed again with
                               JavaScriptSerializer, which keeps such keys apart.
          JavaScriptSerializer System.Web.Script.Serialization.JavaScriptSerializer (Windows PowerShell 5.1 only).
        Invalid JSON throws a terminating error.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [ValidateSet('Auto', 'SystemTextJson', 'ConvertFromJson', 'JavaScriptSerializer')]
        [string]$Engine = 'Auto'
    )

    if ($Engine -eq 'Auto') {
        if ($PSVersionTable.PSEdition -eq 'Core') {
            $Engine = 'SystemTextJson'
        }
        else {
            $Engine = 'ConvertFromJson'
        }
    }

    switch ($Engine) {
        'SystemTextJson' {
            $options = New-Object -TypeName System.Text.Json.JsonDocumentOptions
            $options.AllowTrailingCommas = $true
            $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
            $options.MaxDepth = 1024
            $document = $null
            try {
                $document = [System.Text.Json.JsonDocument]::Parse($Text, $options)
                return ConvertTo-OpenApiRawNode -InputObject $document.RootElement
            }
            catch {
                throw "The document is not valid JSON: $($_.Exception.Message)"
            }
            finally {
                if ($null -ne $document) {
                    $document.Dispose()
                }
            }
        }
        'ConvertFromJson' {
            try {
                $parsed = ConvertFrom-Json -InputObject $Text -ErrorAction Stop
            }
            catch {
                $firstError = $_
                if ($PSVersionTable.PSEdition -eq 'Core') {
                    throw "The document is not valid JSON: $($firstError.Exception.Message)"
                }
                Write-Verbose "ConvertFrom-Json failed ($($firstError.Exception.Message)); parsing with JavaScriptSerializer."
                try {
                    return ConvertFrom-OpenApiJson -Text $Text -Engine 'JavaScriptSerializer'
                }
                catch {
                    throw "The document is not valid JSON: $($firstError.Exception.Message)"
                }
            }
            return ConvertTo-OpenApiRawNode -InputObject $parsed
        }
        'JavaScriptSerializer' {
            Add-Type -AssemblyName System.Web.Extensions -ErrorAction Stop
            $serializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer
            $serializer.MaxJsonLength = [int]::MaxValue
            $serializer.RecursionLimit = 1024
            try {
                $parsed = $serializer.DeserializeObject($Text)
            }
            catch {
                throw "The document is not valid JSON: $($_.Exception.Message)"
            }
            return ConvertTo-OpenApiRawNode -InputObject $parsed
        }
    }
}
