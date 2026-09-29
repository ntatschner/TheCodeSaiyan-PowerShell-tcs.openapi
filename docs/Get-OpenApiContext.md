---
external help file: tcs.openapi-help.xml
Module Name: tcs.openapi
online version:
schema: 2.0.0
---

# Get-OpenApiContext

## SYNOPSIS
Returns the stored connections of OpenAPI services, with every secret shown as ********.

## SYNTAX

```
Get-OpenApiContext [[-Service] <String>] [<CommonParameters>]
```

## DESCRIPTION
Get-OpenApiContext returns the context set with Set-OpenApiContext for one service, or for every service when
no name is given.
Contexts saved with -Persist in an earlier session are loaded too.
Secrets (API key, bearer
token, client secret, passwords and sensitive header values) are never returned; they are shown as ********.

## EXAMPLES

### EXAMPLE 1
```
Get-OpenApiContext -Service 'PetStore'
```

Shows the connection of the PetStore service.

### EXAMPLE 2
```
Get-OpenApiContext | Select-Object -Property Service, BaseUri, Persisted
```

Lists every stored connection.

## PARAMETERS

### -Service
The service name.
Wildcards are allowed.
Without it, every context is returned.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: True
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
### This function does not accept pipeline input.
## OUTPUTS

### Tcs.OpenApi.Context
### Service, BaseUri, ApiKey, Credential, BearerToken, ClientId, ClientSecret, TokenUri, Scope, Header,
### TimeoutSec, Proxy, ProxyCredential, SkipCertificateCheck, MaxRetries and Persisted.
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[Set-OpenApiContext]()

