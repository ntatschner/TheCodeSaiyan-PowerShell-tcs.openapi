function ConvertFrom-OpenApiResponseJson {
    <#
    .SYNOPSIS
        Parses JSON text into objects without rewriting values (date strings stay strings where ConvertFrom-Json allows it).
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $null
    }
    $parameters = @{ InputObject = $Text; ErrorAction = 'Stop' }
    $command = Get-Command -Name 'ConvertFrom-Json' -CommandType Cmdlet
    if ($command.Parameters.ContainsKey('DateKind')) {
        # PowerShell 7.5+: keep date-like strings as strings
        $parameters['DateKind'] = 'String'
    }
    if ($command.Parameters.ContainsKey('NoEnumerate')) {
        $parameters['NoEnumerate'] = $true
    }
    $value = ConvertFrom-Json @parameters
    return , $value
}
