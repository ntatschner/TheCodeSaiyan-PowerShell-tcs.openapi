function ConvertFrom-OpenApiText {
    <#
    .SYNOPSIS
        Parses document text (JSON or YAML) into the raw document tree.
    .DESCRIPTION
        Format 'Auto' treats text whose first non-blank character is '{' or '[' as JSON and anything else as
        YAML. YAML needs ConvertFrom-Yaml from the powershell-yaml module; without it a terminating error
        explains how to install it or convert the document to JSON.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text,

        [ValidateSet('Auto', 'Json', 'Yaml')]
        [string]$Format = 'Auto'
    )

    if ($Text.Length -gt 0 -and $Text[0] -eq [char]0xFEFF) {
        $Text = $Text.Substring(1)
    }
    if ([string]::IsNullOrWhiteSpace($Text)) {
        throw 'The document is empty.'
    }
    if ($Format -eq 'Auto') {
        $first = $Text.TrimStart()[0]
        if ($first -eq '{' -or $first -eq '[') {
            $Format = 'Json'
        }
        else {
            $Format = 'Yaml'
        }
    }

    if ($Format -eq 'Json') {
        return ConvertFrom-OpenApiJson -Text $Text
    }

    $converter = Get-OpenApiYamlConverter
    if ($null -eq $converter) {
        $exception = New-Object -TypeName System.NotSupportedException -ArgumentList ('The document is YAML, which needs the ConvertFrom-Yaml command from the powershell-yaml module. ' +
            'Install it with "Install-Module powershell-yaml -Scope CurrentUser", or convert the document to JSON.')
        $record = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList $exception, 'OpenApi.YamlNotSupported', ([System.Management.Automation.ErrorCategory]::NotInstalled), $null
        throw $record
    }

    $arguments = @{ Yaml = $Text }
    if ($converter -is [System.Management.Automation.CommandInfo] -and $converter.Parameters.ContainsKey('Ordered')) {
        $arguments['Ordered'] = $true
    }
    try {
        $parsed = & $converter @arguments
    }
    catch {
        throw "The document is not valid YAML: $($_.Exception.Message)"
    }
    return ConvertTo-OpenApiRawNode -InputObject $parsed
}
