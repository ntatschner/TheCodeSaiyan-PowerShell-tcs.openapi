function Get-OpenApiCertificateBypassCallback {
    <#
    .SYNOPSIS
        Returns a compiled server certificate validation callback that accepts any certificate (for -SkipCertificateCheck).
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param()

    # PowerShell 7 (.NET Core 3.0 and later) ships a ready-made callback
    $property = [System.Net.Http.HttpClientHandler].GetProperty('DangerousAcceptAnyServerCertificateValidator')
    if ($null -ne $property) {
        return $property.GetValue($null)
    }

    # Windows PowerShell 5.1 (.NET Framework 4.7.1 and later): a script block cannot be used because the
    # callback runs on a thread without a runspace, so a small compiled method is used instead.
    if ($null -eq [System.Net.Http.HttpClientHandler].GetProperty('ServerCertificateCustomValidationCallback')) {
        throw (New-Object System.PlatformNotSupportedException -ArgumentList '-SkipCertificateCheck needs .NET Framework 4.7.1 or later (HttpClientHandler.ServerCertificateCustomValidationCallback). Install a newer .NET Framework or use PowerShell 7.')
    }
    if (-not ('TcsOpenApi.CertificateBypass' -as [type])) {
        $source = @'
namespace TcsOpenApi
{
    public static class CertificateBypass
    {
        public static bool Accept(System.Net.Http.HttpRequestMessage message, System.Security.Cryptography.X509Certificates.X509Certificate2 certificate, System.Security.Cryptography.X509Certificates.X509Chain chain, System.Net.Security.SslPolicyErrors errors)
        {
            return true;
        }

        public static System.Func<System.Net.Http.HttpRequestMessage, System.Security.Cryptography.X509Certificates.X509Certificate2, System.Security.Cryptography.X509Certificates.X509Chain, System.Net.Security.SslPolicyErrors, bool> Callback
        {
            get { return Accept; }
        }
    }
}
'@
        Add-Type -TypeDefinition $source -ReferencedAssemblies @('System.Net.Http', 'System') -ErrorAction Stop
    }
    return ('TcsOpenApi.CertificateBypass' -as [type])::Callback
}
