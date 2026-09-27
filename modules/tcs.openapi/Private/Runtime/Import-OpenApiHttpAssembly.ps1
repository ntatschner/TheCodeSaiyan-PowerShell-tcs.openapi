function Import-OpenApiHttpAssembly {
    <#
    .SYNOPSIS
        Loads System.Net.Http (not loaded by default in Windows PowerShell 5.1) and enables TLS 1.2 on .NET Framework.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    if (-not ('System.Net.Http.HttpClient' -as [type])) {
        Add-Type -AssemblyName 'System.Net.Http' -ErrorAction Stop
    }
    if ($PSVersionTable.PSEdition -ne 'Core') {
        # .NET Framework may default to TLS 1.0/1.1 only; HttpClientHandler uses ServicePointManager there
        $tls12 = [System.Net.SecurityProtocolType]::Tls12
        if (([System.Net.ServicePointManager]::SecurityProtocol -band $tls12) -ne $tls12) {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor $tls12
        }
    }
}
