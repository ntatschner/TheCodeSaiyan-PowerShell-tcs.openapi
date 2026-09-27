function Get-OpenApiGenParameterType {
    <#
    .SYNOPSIS
        Maps a schema to a PowerShell parameter type, validation attributes and an example value.

    .DESCRIPTION
        string -> string (date-time -> datetime, binary -> object), integer -> int (int32) or long,
        number -> double, boolean -> switch when optional and not in the path, otherwise bool,
        array -> element type[], object -> hashtable, anything else -> object. Nullable schemas get
        [AllowNull()]. enum -> [ValidateSet()] (array items too), pattern -> [ValidatePattern()]
        (case-sensitive; skipped when it is not a valid .NET pattern), minimum/maximum ->
        [ValidateRange()] (exclusiveMinimum/exclusiveMaximum as a flag or as the bound), minLength/maxLength -> [ValidateLength()], minItems/maxItems ->
        [ValidateCount()].
        A schema stub without a type (RefName, no properties) is looked up in -Schemas first.
        Returns { TypeName, IsSwitch, Attributes (attribute source lines), ExampleText (PowerShell
        source for a sample value) }.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Schema,

        [Parameter(Mandatory = $true)]
        [ValidateSet('path', 'query', 'header', 'cookie', 'body')]
        [string]$In,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [AllowNull()]
        [object]$Example,

        [Parameter()]
        [AllowNull()]
        [object]$Schemas
    )

    $invariant = [System.Globalization.CultureInfo]::InvariantCulture
    # A stub without a type needs the named schema to find out what it is
    $nullable = ($null -ne $Schema -and $Schema.Nullable -eq $true)
    if ($null -ne $Schema -and [string]::IsNullOrEmpty([string]$Schema.Type)) {
        $Schema = Resolve-OpenApiGenSchema -Schema $Schema -Schemas $Schemas
    }
    $scalarType = {
        param($ItemSchema)
        if ($null -eq $ItemSchema) {
            return 'object'
        }
        $oneOf = @($ItemSchema.OneOf) + @($ItemSchema.AnyOf) | Where-Object -FilterScript { $null -ne $_ }
        if (@($oneOf).Count -gt 0) {
            return 'object'
        }
        switch ([string]$ItemSchema.Type) {
            'string' {
                if ($ItemSchema.Format -eq 'date-time') { return 'datetime' }
                if ($ItemSchema.Format -eq 'binary') { return 'object' }
                return 'string'
            }
            'integer' {
                if ($ItemSchema.Format -eq 'int32') { return 'int' }
                return 'long'
            }
            'number' { return 'double' }
            'boolean' { return 'bool' }
            'object' { return 'hashtable' }
            'array' { return 'array' }
        }
        if (@(Get-OpenApiGenMapEntry -Map $ItemSchema.Properties).Count -gt 0) {
            return 'hashtable'
        }
        return 'object'
    }

    $baseType = & $scalarType $Schema
    $valueSchema = $Schema
    $typeName = $baseType
    if ($baseType -eq 'array') {
        $valueSchema = $Schema.Items
        if ($null -ne $valueSchema -and [string]::IsNullOrEmpty([string]$valueSchema.Type)) {
            $valueSchema = Resolve-OpenApiGenSchema -Schema $valueSchema -Schemas $Schemas
        }
        $elementType = & $scalarType $valueSchema
        if ($elementType -eq 'array') {
            $typeName = 'object[]'
            $valueSchema = $null
        }
        else {
            $typeName = $elementType + '[]'
        }
    }
    $elementName = $typeName.TrimEnd('[', ']')
    $isSwitch = ($typeName -eq 'bool') -and (-not $Required) -and ($In -ne 'path')
    if ($isSwitch) {
        $typeName = 'switch'
    }

    $attributes = New-Object -TypeName System.Collections.ArrayList
    if (($nullable -or ($null -ne $Schema -and $Schema.Nullable -eq $true)) -and -not $isSwitch) {
        [void]$attributes.Add('[AllowNull()]')
    }

    if ($null -ne $valueSchema -and -not $isSwitch -and $elementName -ne 'bool') {
        # enum
        $enumValues = @($valueSchema.Enum | Where-Object -FilterScript { $null -ne $_ -and -not ($_ -is [bool]) })
        if ($enumValues.Count -gt 0 -and @('string', 'int', 'long', 'double') -contains $elementName) {
            $literals = @()
            foreach ($value in $enumValues) {
                $text = [string]$value
                if ($value -is [System.IFormattable]) {
                    $text = $value.ToString($null, $invariant)
                }
                $literal = ConvertTo-OpenApiGenLiteral -Value $text
                if ($literals -notcontains $literal) {
                    $literals += $literal
                }
            }
            [void]$attributes.Add('[ValidateSet(' + ($literals -join ', ') + ')]')
        }
        elseif ($elementName -eq 'string') {
            # pattern and length
            if (-not [string]::IsNullOrEmpty([string]$valueSchema.Pattern)) {
                $validPattern = $true
                try {
                    [void](New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList ([string]$valueSchema.Pattern))
                }
                catch {
                    $validPattern = $false
                }
                if ($validPattern) {
                    [void]$attributes.Add('[ValidatePattern(' + (ConvertTo-OpenApiGenLiteral -Value ([string]$valueSchema.Pattern)) + ', Options = ''None'')]')
                }
            }
            if ($null -ne $valueSchema.MinLength -or $null -ne $valueSchema.MaxLength) {
                $minLength = 0
                $maxLength = [int]::MaxValue
                if ($null -ne $valueSchema.MinLength) { $minLength = [int][math]::Min([double]$valueSchema.MinLength, [int]::MaxValue) }
                if ($null -ne $valueSchema.MaxLength) { $maxLength = [int][math]::Min([double]$valueSchema.MaxLength, [int]::MaxValue) }
                if ($minLength -le $maxLength -and $maxLength -gt 0) {
                    [void]$attributes.Add('[ValidateLength(' + $minLength.ToString($invariant) + ', ' + $maxLength.ToString($invariant) + ')]')
                }
            }
        }
        $hasBound = ($null -ne $valueSchema.Minimum -or $null -ne $valueSchema.Maximum -or ($null -ne $valueSchema.ExclusiveMinimum -and -not ($valueSchema.ExclusiveMinimum -is [bool])) -or ($null -ne $valueSchema.ExclusiveMaximum -and -not ($valueSchema.ExclusiveMaximum -is [bool])))
        if (@('int', 'long', 'double') -contains $elementName -and $hasBound -and $enumValues.Count -eq 0) {
            if ($elementName -eq 'double') {
                $low = -1.7976931348623157E+308
                $high = 1.7976931348623157E+308
                foreach ($bound in @($valueSchema.Minimum, $valueSchema.ExclusiveMinimum)) {
                    if ($null -ne $bound -and -not ($bound -is [bool])) { $low = [double]$bound }
                }
                foreach ($bound in @($valueSchema.Maximum, $valueSchema.ExclusiveMaximum)) {
                    if ($null -ne $bound -and -not ($bound -is [bool])) { $high = [double]$bound }
                }
                $format = {
                    param([double]$Number)
                    $text = $Number.ToString('R', $invariant)
                    if ($text -notmatch '[.E]') {
                        $text += '.0'
                    }
                    return $text
                }
                if ($low -le $high) {
                    [void]$attributes.Add('[ValidateRange(' + (& $format $low) + ', ' + (& $format $high) + ')]')
                }
            }
            else {
                # Same-typed literals: int, or long with the 'l' suffix
                $limit = [double][long]::MaxValue
                $suffix = 'l'
                if ($elementName -eq 'int') {
                    $limit = [double][int]::MaxValue
                    $suffix = ''
                }
                $low = - $limit
                $high = $limit
                # exclusiveMinimum/Maximum: a flag (OAS 3.0) or the bound itself (OAS 3.1)
                $minimum = $valueSchema.Minimum
                $minimumExclusive = ($valueSchema.ExclusiveMinimum -is [bool]) -and $valueSchema.ExclusiveMinimum
                if ($null -ne $valueSchema.ExclusiveMinimum -and -not ($valueSchema.ExclusiveMinimum -is [bool])) {
                    $minimum = $valueSchema.ExclusiveMinimum
                    $minimumExclusive = $true
                }
                $maximum = $valueSchema.Maximum
                $maximumExclusive = ($valueSchema.ExclusiveMaximum -is [bool]) -and $valueSchema.ExclusiveMaximum
                if ($null -ne $valueSchema.ExclusiveMaximum -and -not ($valueSchema.ExclusiveMaximum -is [bool])) {
                    $maximum = $valueSchema.ExclusiveMaximum
                    $maximumExclusive = $true
                }
                if ($null -ne $minimum) {
                    $low = [math]::Ceiling([double]$minimum)
                    if ($minimumExclusive -and $low -eq [double]$minimum) { $low++ }
                }
                if ($null -ne $maximum) {
                    $high = [math]::Floor([double]$maximum)
                    if ($maximumExclusive -and $high -eq [double]$maximum) { $high-- }
                }
                $low = [math]::Max($low, - $limit)
                $high = [math]::Min($high, $limit)
                $format = {
                    param([double]$Number)
                    if ($Number -ge [double][long]::MaxValue) {
                        return '9223372036854775807' + $suffix
                    }
                    if ($Number -le - [double][long]::MaxValue) {
                        return '-9223372036854775807' + $suffix
                    }
                    return ([long]$Number).ToString($invariant) + $suffix
                }
                if ($low -le $high) {
                    [void]$attributes.Add('[ValidateRange(' + (& $format $low) + ', ' + (& $format $high) + ')]')
                }
            }
        }
    }
    if ($baseType -eq 'array' -and ($null -ne $Schema.MinItems -or $null -ne $Schema.MaxItems)) {
        $minItems = 0
        $maxItems = [int]::MaxValue
        if ($null -ne $Schema.MinItems) { $minItems = [int][math]::Min([double]$Schema.MinItems, [int]::MaxValue) }
        if ($null -ne $Schema.MaxItems) { $maxItems = [int][math]::Min([double]$Schema.MaxItems, [int]::MaxValue) }
        if ($minItems -le $maxItems -and $maxItems -gt 0) {
            [void]$attributes.Add('[ValidateCount(' + $minItems.ToString($invariant) + ', ' + $maxItems.ToString($invariant) + ')]')
        }
    }

    # Example value, as PowerShell source
    $sample = $Example
    if ($null -eq $sample -and $null -ne $Schema -and $null -ne $Schema.Example -and $typeName -notlike '*[[]]') {
        $sample = $Schema.Example
    }
    if ($null -eq $sample -and $null -ne $valueSchema) {
        $enumSample = @($valueSchema.Enum | Where-Object -FilterScript { $null -ne $_ })
        if ($enumSample.Count -gt 0) {
            $sample = $enumSample[0]
        }
        elseif ($null -ne $valueSchema.Default) {
            $sample = $valueSchema.Default
        }
    }
    if ($sample -is [System.Collections.IEnumerable] -and -not ($sample -is [string])) {
        $sample = $null
    }
    $exampleText = $null
    switch ($elementName) {
        'string' {
            $text = 'example'
            if ($null -ne $sample -and -not ($sample -is [System.Collections.IDictionary]) -and -not ($sample -is [System.Management.Automation.PSCustomObject])) {
                $text = [string]$sample
                if ($sample -is [System.IFormattable]) { $text = $sample.ToString($null, $invariant) }
            }
            $exampleText = ConvertTo-OpenApiGenLiteral -Value $text
        }
        'datetime' { $exampleText = '(Get-Date)' }
        { @('int', 'long', 'double') -contains $_ } {
            $number = 1
            if ($null -ne $sample) {
                $parsed = 0.0
                if ([double]::TryParse([string]$sample, [System.Globalization.NumberStyles]::Float, $invariant, [ref]$parsed)) {
                    $number = $parsed
                }
            }
            $exampleText = ([double]$number).ToString('R', $invariant)
        }
        'bool' { $exampleText = '$true' }
        'hashtable' { $exampleText = '@{}' }
        default { $exampleText = "'example'" }
    }
    if ($typeName.EndsWith('[]')) {
        $exampleText = '@(' + $exampleText + ')'
    }
    if ($isSwitch) {
        $exampleText = $null
    }

    return [pscustomobject]@{
        TypeName    = $typeName
        IsSwitch    = $isSwitch
        Attributes  = $attributes.ToArray()
        ExampleText = $exampleText
    }
}
