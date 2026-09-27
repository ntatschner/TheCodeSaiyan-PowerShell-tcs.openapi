function Build-OpenApiBinaryContent {
    <#
    .SYNOPSIS
        Creates HttpContent from a byte array, a stream, a FileInfo or text (sent as UTF-8 bytes).
    #>
    [CmdletBinding()]
    [OutputType([System.Net.Http.HttpContent])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Value
    )

    if ($Value -is [System.Management.Automation.PSObject]) {
        $Value = $Value.PSObject.BaseObject
    }
    if ($null -eq $Value) {
        return (New-Object System.Net.Http.ByteArrayContent -ArgumentList (, [byte[]]@()))
    }
    if ($Value -is [byte[]]) {
        return (New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $Value))
    }
    if ($Value -is [System.IO.FileInfo]) {
        if (-not $Value.Exists) {
            throw (New-Object System.IO.FileNotFoundException -ArgumentList "The file '$($Value.FullName)' does not exist.", $Value.FullName)
        }
        # The stream is disposed with the content, after the request is sent
        $stream = [System.IO.File]::OpenRead($Value.FullName)
        return (New-Object System.Net.Http.StreamContent -ArgumentList $stream)
    }
    if ($Value -is [System.IO.Stream]) {
        if ($Value.CanSeek) {
            $Value.Position = 0
        }
        # Wrap so that disposing the request does not close the caller's stream
        $buffer = New-Object System.IO.MemoryStream
        $Value.CopyTo($buffer)
        $buffer.Position = 0
        return (New-Object System.Net.Http.StreamContent -ArgumentList $buffer)
    }
    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    return (New-Object System.Net.Http.ByteArrayContent -ArgumentList (, $utf8.GetBytes((ConvertTo-OpenApiScalarString -Value $Value))))
}
