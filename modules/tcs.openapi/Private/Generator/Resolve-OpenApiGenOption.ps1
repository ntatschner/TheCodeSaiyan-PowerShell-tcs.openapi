function Resolve-OpenApiGenOption {
    <#
    .SYNOPSIS
        Resolves the options of one generation run into a single object.

    .DESCRIPTION
        Service = ModuleName. Prefix (used for the connection commands) = NounPrefix, or the PascalCase
        module name when there is no NounPrefix. ModuleVersion defaults to 0.1.0 and Author to
        'tcs.openapi', so the output never depends on the machine or user that runs the generator.
        ModulePath = OutputPath/ModuleName.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath,

        [Parameter()]
        [AllowEmptyString()]
        [string]$NounPrefix = '',

        [Parameter()]
        [AllowNull()]
        [version]$ModuleVersion,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Author,

        [Parameter(Mandatory = $true)]
        [string]$GeneratorVersion
    )

    if ($ModuleName -notmatch '^[A-Za-z][A-Za-z0-9._-]*$') {
        throw "The module name '$ModuleName' is not valid: use letters, digits, '.', '_' and '-', starting with a letter."
    }
    if ($NounPrefix -ne '' -and $NounPrefix -notmatch '^[A-Za-z][A-Za-z0-9]*$') {
        throw "The noun prefix '$NounPrefix' is not valid: use letters and digits, starting with a letter."
    }
    $prefix = $NounPrefix
    if ($prefix -eq '') {
        $prefix = ConvertTo-OpenApiGenPascalCase -Value $ModuleName
    }
    $version = '0.1.0'
    if ($null -ne $ModuleVersion) {
        $version = $ModuleVersion.ToString()
    }
    $moduleAuthor = 'tcs.openapi'
    if (-not [string]::IsNullOrWhiteSpace($Author)) {
        $moduleAuthor = $Author
    }

    return [pscustomobject]@{
        PSTypeName       = 'Tcs.OpenApi.GenerationOption'
        ModuleName       = $ModuleName
        Service          = $ModuleName
        OutputPath       = $OutputPath
        ModulePath       = (Join-Path -Path $OutputPath -ChildPath $ModuleName)
        NounPrefix       = $NounPrefix
        Prefix           = $prefix
        ModuleVersion    = $version
        Author           = $moduleAuthor
        GeneratorVersion = $GeneratorVersion
    }
}
