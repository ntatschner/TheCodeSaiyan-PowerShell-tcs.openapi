function ConvertFrom-OpenApiSwagger2Operation {
    <#
    .SYNOPSIS
        Converts a Swagger 2.0 operation (with its path-level parameters) to an OpenAPI 3 operation.
    .DESCRIPTION
        - '#/parameters/...' and '#/responses/...' refs are inlined (unresolvable ones are left for the
          normaliser to report).
        - Path-level parameters are merged in; operation-level ones win on (name, in).
        - The body parameter becomes requestBody with one media type per consumes type.
        - formData parameters become a requestBody object schema (properties + required) with
          multipart/form-data when any parameter is a file (or consumes lists only multipart/form-data),
          otherwise application/x-www-form-urlencoded.
        - consumes/produces default to the document's, then to application/json.
        - x- extensions are kept.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Root,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Operation,

        [AllowNull()]
        [object]$PathParameters,

        [AllowEmptyCollection()]
        [string[]]$Consumes = @(),

        [AllowEmptyCollection()]
        [string[]]$Produces = @()
    )

    $result = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    foreach ($key in @($Operation.Keys)) {
        if ($key -cin @('tags', 'summary', 'description', 'externalDocs', 'operationId', 'deprecated', 'security') -or $key.StartsWith('x-')) {
            $result[$key] = $Operation[$key]
        }
    }

    if ($Operation.Contains('consumes')) {
        $Consumes = @($Operation['consumes'] | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    }
    if ($Consumes.Count -eq 0) {
        $Consumes = @('application/json')
    }
    if ($Operation.Contains('produces')) {
        $Produces = @($Operation['produces'] | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
    }
    if ($Produces.Count -eq 0) {
        $Produces = @('application/json')
    }

    # Merge path-level and operation-level parameters, resolving '#/parameters/...' refs
    $merged = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
    foreach ($source in @($PathParameters, $Operation['parameters'])) {
        if ($source -isnot [System.Collections.IList]) {
            continue
        }
        foreach ($raw in $source) {
            $parameter = $raw
            if ($parameter -is [System.Collections.IDictionary] -and $parameter.Contains('$ref')) {
                $target = Resolve-OpenApiPointer -Root $Root -Reference ([string]$parameter['$ref'])
                if ($target.Found -and $target.Value -is [System.Collections.IDictionary]) {
                    $parameter = $target.Value
                }
            }
            if ($parameter -isnot [System.Collections.IDictionary]) {
                continue
            }
            if ($parameter.Contains('$ref')) {
                $key = 'ref|' + [string]$parameter['$ref']
            }
            else {
                $key = '{0}|{1}' -f $parameter['in'], $parameter['name']
            }
            $merged[$key] = $parameter
        }
    }

    $parameters = [System.Collections.Generic.List[object]]::new()
    $body = $null
    $formData = [System.Collections.Generic.List[object]]::new()
    foreach ($parameter in $merged.Values) {
        if ($parameter.Contains('$ref')) {
            $parameters.Add($parameter)
            continue
        }
        switch ([string]$parameter['in']) {
            'body' {
                $body = $parameter
            }
            'formData' {
                $formData.Add($parameter)
            }
            default {
                $parameters.Add((ConvertFrom-OpenApiSwagger2Parameter -Node $parameter))
            }
        }
    }
    if ($parameters.Count -gt 0) {
        $result['parameters'] = $parameters.ToArray()
    }

    if ($null -ne $body) {
        $requestBody = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        if ($body.Contains('description')) {
            $requestBody['description'] = $body['description']
        }
        $requestBody['required'] = $body['required'] -eq $true
        $content = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($contentType in $Consumes) {
            $media = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
            $media['schema'] = $body['schema']
            $content[$contentType] = $media
        }
        $requestBody['content'] = $content
        foreach ($key in @($body.Keys)) {
            if ($key.StartsWith('x-')) {
                $requestBody[$key] = $body[$key]
            }
        }
        $result['requestBody'] = $requestBody
    }
    elseif ($formData.Count -gt 0) {
        $hasFile = @($formData | Where-Object { [string]$_['type'] -ceq 'file' }).Count -gt 0
        $multipartOnly = ($Consumes -contains 'multipart/form-data') -and -not ($Consumes -contains 'application/x-www-form-urlencoded')
        $contentType = 'application/x-www-form-urlencoded'
        if ($hasFile -or $multipartOnly) {
            $contentType = 'multipart/form-data'
        }
        $properties = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $required = [System.Collections.Generic.List[string]]::new()
        foreach ($parameter in $formData) {
            $property = ConvertFrom-OpenApiSwagger2SimpleSchema -Node $parameter
            if ($parameter.Contains('description')) {
                $property['description'] = $parameter['description']
            }
            $properties[[string]$parameter['name']] = $property
            if ($parameter['required'] -eq $true) {
                $required.Add([string]$parameter['name'])
            }
        }
        $schema = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $schema['type'] = 'object'
        $schema['properties'] = $properties
        if ($required.Count -gt 0) {
            $schema['required'] = [object[]]$required.ToArray()
        }
        $media = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $media['schema'] = $schema
        $content = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $content[$contentType] = $media
        $requestBody = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        $requestBody['required'] = $required.Count -gt 0
        $requestBody['content'] = $content
        $result['requestBody'] = $requestBody
    }

    if ($Operation['responses'] -is [System.Collections.IDictionary]) {
        $responses = [System.Collections.Specialized.OrderedDictionary]::new([System.StringComparer]::Ordinal)
        foreach ($code in @($Operation['responses'].Keys)) {
            $response = $Operation['responses'][$code]
            if ($response -is [System.Collections.IDictionary] -and $response.Contains('$ref')) {
                $target = Resolve-OpenApiPointer -Root $Root -Reference ([string]$response['$ref'])
                if ($target.Found -and $target.Value -is [System.Collections.IDictionary]) {
                    $response = $target.Value
                }
                else {
                    $responses[$code] = $response
                    continue
                }
            }
            if ($response -is [System.Collections.IDictionary]) {
                $responses[$code] = ConvertFrom-OpenApiSwagger2Response -Node $response -Produces $Produces
            }
        }
        $result['responses'] = $responses
    }
    return $result
}
