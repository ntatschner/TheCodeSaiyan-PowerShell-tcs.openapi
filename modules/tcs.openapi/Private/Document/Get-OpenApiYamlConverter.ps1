function Get-OpenApiYamlConverter {
    <#
    .SYNOPSIS
        Returns the ConvertFrom-Yaml command (powershell-yaml) when it is available, otherwise nothing.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CommandInfo])]
    param()

    Get-Command -Name 'ConvertFrom-Yaml' -CommandType Function, Cmdlet -ErrorAction SilentlyContinue | Select-Object -First 1
}
