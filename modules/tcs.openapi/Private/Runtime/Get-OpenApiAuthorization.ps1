function Get-OpenApiAuthorization {
    <#
    .SYNOPSIS
        Returns the headers, query pairs and cookies that authenticate a request, for the security requirement selected for the operation.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object]$Operation,

        [Parameter(Mandatory)]
        [pscustomobject]$Context,

        [Parameter(Mandatory)]
        [System.Net.Http.HttpClient]$Client,

        [Parameter()]
        [switch]$ForceRefresh
    )

    $headers = [ordered]@{}
    $query = New-Object System.Collections.Generic.List[string]
    $cookies = New-Object System.Collections.Generic.List[string]
    $sensitive = New-Object System.Collections.Generic.List[string]
    $usesOAuth = $false

    $selection = Select-OpenApiSecurityRequirement -Operation $Operation -Context $Context
    $schemes = @($selection.Schemes)
    if ($selection.Mode -eq 'Generic') {
        # No security metadata (for example a hand-written operation): use what the context has
        if ($null -ne $Context.BearerToken) {
            $schemes = @([pscustomobject]@{ Name = 'bearer'; Scheme = @{ Type = 'http'; Scheme = 'bearer' }; Scopes = @() })
        }
        elseif ($null -ne $Context.Credential) {
            $schemes = @([pscustomobject]@{ Name = 'basic'; Scheme = @{ Type = 'http'; Scheme = 'basic' }; Scopes = @() })
        }
        elseif (-not [string]::IsNullOrEmpty($Context.ClientId) -and $null -ne $Context.ClientSecret -and -not [string]::IsNullOrEmpty($Context.TokenUri)) {
            $schemes = @([pscustomobject]@{ Name = 'oauth2'; Scheme = @{ Type = 'oauth2' }; Scopes = @() })
        }
    }
    elseif ($selection.Mode -eq 'Unsatisfied') {
        Write-Verbose -Message "The context of '$($Context.Service)' has no credentials for any security requirement of this operation; sending the request without authentication."
    }

    foreach ($entry in $schemes) {
        $scheme = $entry.Scheme
        $type = [string](Get-OpenApiMember -InputObject $scheme -Name 'Type')
        switch ($type) {
            'apiKey' {
                $parameterName = [string](Get-OpenApiMember -InputObject $scheme -Name 'ParameterName')
                if ([string]::IsNullOrEmpty($parameterName)) {
                    $parameterName = [string](Get-OpenApiMember -InputObject $scheme -Name 'Name')
                }
                $location = [string](Get-OpenApiMember -InputObject $scheme -Name 'In')
                $value = ConvertFrom-OpenApiSecureString -SecureString $Context.ApiKey
                $sensitive.Add($parameterName)
                if ($location -eq 'query') {
                    $query.Add((ConvertTo-OpenApiUriEncoded -Value $parameterName) + '=' + (ConvertTo-OpenApiUriEncoded -Value $value))
                }
                elseif ($location -eq 'cookie') {
                    $cookies.Add((ConvertTo-OpenApiUriEncoded -Value $parameterName) + '=' + (ConvertTo-OpenApiUriEncoded -Value $value))
                }
                else {
                    $headers[$parameterName] = $value
                }
            }
            'http' {
                $httpScheme = ([string](Get-OpenApiMember -InputObject $scheme -Name 'Scheme')).ToLowerInvariant()
                if ($httpScheme -eq 'basic') {
                    $pair = $Context.Credential.UserName + ':' + $Context.Credential.GetNetworkCredential().Password
                    $headers['Authorization'] = 'Basic ' + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pair))
                    $pair = $null
                }
                else {
                    $headers['Authorization'] = 'Bearer ' + (ConvertFrom-OpenApiSecureString -SecureString $Context.BearerToken)
                }
            }
            default {
                # oauth2 / openIdConnect: a supplied bearer token wins, else client credentials
                if ($type -eq 'oauth2' -and ($null -eq $Context.BearerToken)) {
                    $tokenUri = Get-OpenApiTokenUri -Scheme $scheme -Context $Context
                    $scopes = @($Context.Scope)
                    if ($scopes.Count -eq 0) {
                        $scopes = @($entry.Scopes)
                    }
                    $token = Get-OpenApiOAuthToken -Context $Context -Client $Client -TokenUri $tokenUri -Scope $scopes -Force:$ForceRefresh
                    $headers['Authorization'] = 'Bearer ' + (ConvertFrom-OpenApiSecureString -SecureString $token)
                    $usesOAuth = $true
                }
                elseif ($null -ne $Context.BearerToken) {
                    $headers['Authorization'] = 'Bearer ' + (ConvertFrom-OpenApiSecureString -SecureString $Context.BearerToken)
                }
            }
        }
    }

    return [pscustomobject]@{
        Header        = $headers
        Query         = $query.ToArray()
        Cookie        = $cookies.ToArray()
        UsesOAuth     = $usesOAuth
        SensitiveName = $sensitive.ToArray()
    }
}
