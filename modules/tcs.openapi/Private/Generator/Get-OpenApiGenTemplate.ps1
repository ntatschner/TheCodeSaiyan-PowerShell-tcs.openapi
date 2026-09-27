function Get-OpenApiGenTemplate {
    <#
    .SYNOPSIS
        Reads the generated-module templates (*.template) from a folder into a hashtable keyed by file
        name without the '.template' extension ('Function.ps1', 'Module.psd1', ...), with LF line endings.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $templates = @{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Path -Filter '*.template' -File)) {
        $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $templates[$file.Name.Substring(0, $file.Name.Length - '.template'.Length)] = $text.Replace("`r`n", "`n")
    }
    return $templates
}
