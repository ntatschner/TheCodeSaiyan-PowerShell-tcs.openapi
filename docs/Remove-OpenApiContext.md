---
external help file: tcs.openapi-help.xml
Module Name: tcs.openapi
online version:
schema: 2.0.0
---

# Remove-OpenApiContext

## SYNOPSIS
Removes the stored connection of an OpenAPI service.

## SYNTAX

```
Remove-OpenApiContext [-Service] <String> [-Persisted] [-WhatIf]
 [-Confirm] [<CommonParameters>]
```

## DESCRIPTION
Remove-OpenApiContext clears the context of a service from the current session, with its cached HTTP client
and OAuth2 tokens.
With -Persisted it also deletes the saved settings file and the secrets saved with
Set-OpenApiContext -Persist; without it, a saved context is loaded again the next time the service is used.

## EXAMPLES

### EXAMPLE 1
```
Remove-OpenApiContext -Service 'PetStore'
```

Clears the PetStore connection from this session.

### EXAMPLE 2
```
Remove-OpenApiContext -Service 'PetStore' -Persisted
```

Clears the connection and deletes its saved settings and secrets.

## PARAMETERS

### -Service
The service name.

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

### -Persisted
Also deletes the context saved for later sessions (settings and secrets).

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

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None
### This function does not accept pipeline input.
## OUTPUTS

### None
## NOTES
Author: Nigel Tatschner
Company: TheCodeSaiyan

## RELATED LINKS

[Set-OpenApiContext]()

