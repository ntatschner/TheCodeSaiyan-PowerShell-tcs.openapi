function ConvertTo-OpenApiGenReadme {
    <#
    .SYNOPSIS
        Renders README.md of a generated module: how to connect and a table of the commands.

    .DESCRIPTION
        -Function is the list of generated functions ({ Name, Method, Path, Summary }); the table is
        sorted by command name (ordinal). Pipes and line breaks in summaries are escaped for Markdown.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Option,

        [Parameter(Mandatory = $true)]
        [object]$Document,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Function,

        # Empty when the document has no security scheme and has a default server
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$ConnectExample,

        [Parameter(Mandatory = $true)]
        [string]$Template
    )

    $escape = {
        param([string]$Text)
        return ([regex]::Replace(([string]$Text).Trim(), '\s*[\r\n]+\s*', ' ')).Replace('|', '\|')
    }
    $rows = @()
    foreach ($item in (Get-OpenApiGenOrdinalSorted -InputObject $Function -Key { [string]$_.Name })) {
        $method = '-'
        $path = '-'
        if (-not [string]::IsNullOrEmpty([string]$item.Method)) {
            $method = $item.Method
            $path = '`' + (& $escape $item.Path) + '`'
        }
        $rows += '| `' + $item.Name + '` | ' + $method + ' | ' + $path + ' | ' + (& $escape $item.Summary) + ' |'
    }
    $title = ([string]$Document.Title).Trim()
    if ($title -eq '') {
        $title = $Option.ModuleName
    }
    $docVersion = ([string]$Document.Version).Trim()
    if ($docVersion -eq '') {
        $docVersion = 'unknown'
    }
    $description = ([string]$Document.Description).Replace("`r`n", "`n").Trim()
    if ($description -ne '') {
        $description += "`n"
    }

    return Expand-OpenApiGenTemplate -Template $Template -Value @{
        ModuleName       = $Option.ModuleName
        Title            = $title
        DocVersion       = $docVersion
        GeneratorVersion = $Option.GeneratorVersion
        Description      = $description
        Prefix           = $Option.Prefix
        ConnectExample   = $ConnectExample
        CommandTable     = ($rows -join "`n")
    }
}
