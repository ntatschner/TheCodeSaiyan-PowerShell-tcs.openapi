---
external help file: tcs.openapi-help.xml
Module Name: tcs.openapi
online version:
schema: 2.0.0
---

# Set-OpenApiContext

## SYNOPSIS
Stores the connection (base URI, credentials and transport settings) for an OpenAPI service.

## SYNTAX

```
Set-OpenApiContext [-Service] <String> [-BaseUri] <Uri> [[-ApiKey] <SecureString>]
 [[-Credential] <PSCredential>] [[-BearerToken] <SecureString>] [[-ClientId] <String>]
 [[-ClientSecret] <SecureString>] [[-TokenUri] <Uri>] [[-Scope] <String[]>] [[-Header] <Hashtable>]
 [[-TimeoutSec] <Int32>] [[-Proxy] <Uri>] [[-ProxyCredential] <PSCredential>] [-SkipCertificateCheck]
 [[-MaxRetries] <Int32>] [-Persist] [-PassThru] [-ProgressAction <ActionPreference>] [-WhatIf] [-Confirm]
 [<CommonParameters>]
```

## DESCRIPTION
Set-OpenApiContext saves how to reach a service in the current session: its base URI, the credentials for
each kind of security scheme, extra headers, timeout, proxy and retry settings.
Invoke-OpenApiRequest (and every
command of a generated module) uses the context of its service.
Setting a context replaces the previous one of
the same service.

Secrets are kept as SecureString and decoded only when a request is built.
With -Persist the context is also
saved for later sessions: secrets with tcs.core Set-ModuleSecret (module tcs.openapi, names
'\<Service\>.ApiKey', '\<Service\>.BearerToken', '\<Service\>.ClientSecret', '\<Service\>.Credential' and
'\<Service\>.ProxyCredential'), and the other settings as JSON in
'\<config root\>/tcs.openapi/Contexts/\<Service\>.json'.
A later session loads the saved context the first time
the service is used.

## EXAMPLES

### EXAMPLE 1
```
Set-OpenApiContext -Service 'PetStore' -BaseUri 'https://petstore.example.com/v1' -ApiKey (Read-Host -AsSecureString -Prompt 'API key')
```

Connects the PetStore service with an API key for this session.

### EXAMPLE 2
```
$secret = Read-Host -AsSecureString -Prompt 'Client secret'
Set-OpenApiContext -Service 'Billing' -BaseUri 'https://api.example.com' -ClientId 'my-app' -ClientSecret $secret -TokenUri 'https://login.example.com/oauth2/token' -Scope 'billing.read' -Persist
```

Uses OAuth2 client credentials and saves the context for later sessions.

## PARAMETERS

### -Service
The service name, for example the name of a generated module.
Letters, digits, '.', '_' and '-'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: True
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BaseUri
The base URL of the API; operation paths are appended to it.

```yaml
Type: Uri
Parameter Sets: (All)
Aliases:

Required: True
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey
The key used for apiKey security schemes (in a header, query parameter or cookie, as the scheme says).

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Credential
The user name and password used for HTTP basic authentication.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 4
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -BearerToken
The token used for HTTP bearer authentication; it is also used for OAuth2 and OpenID Connect schemes.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 5
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientId
The OAuth2 client ID for the client credentials flow.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 6
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ClientSecret
The OAuth2 client secret for the client credentials flow.

```yaml
Type: SecureString
Parameter Sets: (All)
Aliases:

Required: False
Position: 7
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TokenUri
The OAuth2 token endpoint.
Defaults to the tokenUrl of the scheme's clientCredentials flow.

```yaml
Type: Uri
Parameter Sets: (All)
Aliases:

Required: False
Position: 8
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Scope
The OAuth2 scopes to request.
Defaults to the scopes the operation's security requirement lists.

```yaml
Type: String[]
Parameter Sets: (All)
Aliases:

Required: False
Position: 9
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Header
Headers sent with every request, for example @{ 'X-Tenant' = 'contoso' }.
Values are saved in plain text with
-Persist, so put secrets in -ApiKey or -BearerToken instead.

```yaml
Type: Hashtable
Parameter Sets: (All)
Aliases:

Required: False
Position: 10
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -TimeoutSec
The request timeout in seconds.
0 means no timeout.
Defaults to 100.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 11
Default value: 100
Accept pipeline input: False
Accept wildcard characters: False
```

### -Proxy
The URL of a proxy server to use.

```yaml
Type: Uri
Parameter Sets: (All)
Aliases:

Required: False
Position: 12
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProxyCredential
The credential for the proxy server.

```yaml
Type: PSCredential
Parameter Sets: (All)
Aliases:

Required: False
Position: 13
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -SkipCertificateCheck
Accepts any server certificate.
Use only for test servers.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -MaxRetries
How many times a throttled or failed request is retried.
Defaults to 3.

```yaml
Type: Int32
Parameter Sets: (All)
Aliases:

Required: False
Position: 14
Default value: 3
Accept pipeline input: False
Accept wildcard characters: False
```

### -Persist
Also saves the context (secrets encrypted with tcs.core) for later sessions.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -PassThru
Returns the context, with secrets shown as ********.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -WhatIf
Shows what would happen if the cmdlet runs.
The cmdlet is not run.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: wi

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Confirm
Prompts you for confirmation before running the cmdlet.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases: cf

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
### This function does not accept pipeline input.
## OUTPUTS

### Tcs.OpenApi.Context
### With -PassThru.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[Get-OpenApiContext]()

[Remove-OpenApiContext]()

[Invoke-OpenApiRequest]()

