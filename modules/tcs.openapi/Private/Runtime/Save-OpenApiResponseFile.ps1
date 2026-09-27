function Save-OpenApiResponseFile {
    <#
    .SYNOPSIS
        Streams a response body to a file and returns the FileInfo.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Response,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $folder = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [string]::IsNullOrEmpty($folder) -and -not [System.IO.Directory]::Exists($folder)) {
        throw (New-Object System.IO.DirectoryNotFoundException -ArgumentList "The folder '$folder' of the output file does not exist.")
    }
    $file = [System.IO.File]::Create($Path)
    try {
        if ($null -ne $Response.Message) {
            if ($null -ne $Response.Message.Content) {
                $stream = $Response.Message.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                try {
                    $stream.CopyTo($file)
                }
                finally {
                    $stream.Dispose()
                }
            }
        }
        elseif ($null -ne $Response.Body) {
            $file.Write($Response.Body, 0, $Response.Body.Length)
        }
    }
    finally {
        $file.Dispose()
        if ($null -ne $Response.Message) {
            $Response.Message.Dispose()
            $Response.Message = $null
        }
    }
    Write-Verbose -Message "Saved the response body to '$Path'."
    return (Get-Item -LiteralPath $Path)
}
