function Get-OpenApiOperationId {
    <#
    .SYNOPSIS
        Generates an operationId '<method><PathPascal>' for an operation without one (GET /pets/{petId} -> getPetsPetId).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Path
    )

    $builder = New-Object -TypeName System.Text.StringBuilder -ArgumentList $Method.ToLowerInvariant()
    $segments = @($Path.Split('/') | Where-Object { $_ -ne '' })
    foreach ($segment in $segments) {
        $clean = $segment -replace '[^A-Za-z0-9]+', ' '
        if ([string]::IsNullOrWhiteSpace($clean)) {
            continue
        }
        $pascal = ConvertTo-PascalCase -Value $clean.Trim()
        [void]$builder.Append(($pascal -replace '[^A-Za-z0-9]', ''))
    }
    if ($builder.Length -eq $Method.Length) {
        [void]$builder.Append('Root')
    }
    return $builder.ToString()
}
