function Save-OpenApiContextSetting {
    <#
    .SYNOPSIS
        Persists a context: secrets with tcs.core Set-ModuleSecret (tcs.openapi, <service>.<kind>) and the other settings as JSON.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Context
    )

    $service = $Context.Service
    $path = Get-OpenApiContextSettingPath -Service $service
    $secretKinds = New-Object System.Collections.Generic.List[string]
    foreach ($kind in @('ApiKey', 'BearerToken', 'ClientSecret')) {
        $name = "$service.$kind"
        if ($null -ne $Context.$kind) {
            Set-ModuleSecret -ModuleName 'tcs.openapi' -Name $name -SecureString $Context.$kind -Confirm:$false -WhatIf:$false -ErrorAction Stop
            $secretKinds.Add($kind)
        }
        else {
            Remove-ModuleSecret -ModuleName 'tcs.openapi' -Name $name -Confirm:$false -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }
    foreach ($kind in @('Credential', 'ProxyCredential')) {
        $name = "$service.$kind"
        if ($null -ne $Context.$kind) {
            Set-ModuleSecret -ModuleName 'tcs.openapi' -Name $name -Credential $Context.$kind -Confirm:$false -WhatIf:$false -ErrorAction Stop
            $secretKinds.Add($kind)
        }
        else {
            Remove-ModuleSecret -ModuleName 'tcs.openapi' -Name $name -Confirm:$false -WhatIf:$false -ErrorAction SilentlyContinue
        }
    }

    $settings = [ordered]@{
        Service              = $service
        BaseUri              = $Context.BaseUri
        ClientId             = $Context.ClientId
        TokenUri             = $Context.TokenUri
        Scope                = @($Context.Scope)
        Header               = $Context.Header
        TimeoutSec           = $Context.TimeoutSec
        Proxy                = $Context.Proxy
        SkipCertificateCheck = $Context.SkipCertificateCheck
        MaxRetries           = $Context.MaxRetries
        Secrets              = $secretKinds.ToArray()
        Updated              = [datetime]::UtcNow.ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
    }
    $folder = Split-Path -Path $path -Parent
    if (-not (Test-Path -LiteralPath $folder)) {
        $null = New-Item -Path $folder -ItemType Directory -Force -Confirm:$false -WhatIf:$false -ErrorAction Stop
    }
    $json = ConvertTo-Json -InputObject $settings -Depth 5
    [System.IO.File]::WriteAllText($path, $json, (New-Object System.Text.UTF8Encoding -ArgumentList $false))
}
