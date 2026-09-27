function Import-OpenApiPersistedContext {
    <#
    .SYNOPSIS
        Loads a context saved with Set-OpenApiContext -Persist (settings JSON and module secrets), or returns $null when none is saved.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Service
    )

    $path = Get-OpenApiContextSettingPath -Service $Service
    if (-not (Test-Path -LiteralPath $path)) {
        return $null
    }
    $settings = [System.IO.File]::ReadAllText($path) | ConvertFrom-Json
    $secrets = @{}
    foreach ($kind in @($settings.Secrets)) {
        if ([string]::IsNullOrEmpty($kind)) {
            continue
        }
        try {
            $secrets[$kind] = Get-ModuleSecret -ModuleName 'tcs.openapi' -Name "$Service.$kind" -ErrorAction Stop
        }
        catch {
            Write-Warning -Message "The saved $kind of the '$Service' context could not be read: $($_.Exception.Message)"
        }
    }
    $header = [ordered]@{}
    if ($null -ne $settings.Header) {
        foreach ($property in $settings.Header.PSObject.Properties) {
            $header[$property.Name] = [string]$property.Value
        }
    }
    $timeout = 100
    if ($null -ne $settings.TimeoutSec) {
        $timeout = [int]$settings.TimeoutSec
    }
    $maxRetries = 3
    if ($null -ne $settings.MaxRetries) {
        $maxRetries = [int]$settings.MaxRetries
    }
    $contextParameters = @{
        Service              = $Service
        BaseUri              = [string]$settings.BaseUri
        ApiKey               = $secrets['ApiKey']
        Credential           = $secrets['Credential']
        BearerToken          = $secrets['BearerToken']
        ClientId             = [string]$settings.ClientId
        ClientSecret         = $secrets['ClientSecret']
        TokenUri             = [string]$settings.TokenUri
        Scope                = @($settings.Scope | Where-Object -FilterScript { $null -ne $_ } | ForEach-Object -Process { [string]$_ })
        Header               = $header
        TimeoutSec           = $timeout
        Proxy                = [string]$settings.Proxy
        ProxyCredential      = $secrets['ProxyCredential']
        SkipCertificateCheck = [bool]$settings.SkipCertificateCheck
        MaxRetries           = $maxRetries
        Persisted            = $true
    }
    return (New-OpenApiContext @contextParameters)
}
