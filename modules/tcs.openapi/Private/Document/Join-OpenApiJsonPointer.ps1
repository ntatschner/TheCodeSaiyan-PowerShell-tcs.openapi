function Join-OpenApiJsonPointer {
    <#
    .SYNOPSIS
        Appends escaped segments to a JSON pointer ('~' -> '~0', '/' -> '~1').
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Pointer,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Segment
    )

    $builder = New-Object -TypeName System.Text.StringBuilder -ArgumentList $Pointer
    foreach ($item in $Segment) {
        $escaped = $item.Replace('~', '~0').Replace('/', '~1')
        [void]$builder.Append('/').Append($escaped)
    }
    return $builder.ToString()
}
