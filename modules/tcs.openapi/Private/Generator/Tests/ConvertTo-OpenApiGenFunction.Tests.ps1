BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    $RepoRoot = Split-Path -Path (Split-Path -Path $ModuleRoot -Parent) -Parent
    . (Join-Path -Path $RepoRoot -ChildPath 'tests/Helpers/New-TestOpenApiModel.ps1')
}

Describe 'ConvertTo-OpenApiGenFunction' {
    BeforeAll {
        function ConvertTo-TestFunction {
            param($Operation, [string]$Prefix = 'Shop', [string]$ResponseTypeName)
            InModuleScope tcs.openapi -Parameters @{ Operation = $Operation; Prefix = $Prefix; ResponseTypeName = $ResponseTypeName } {
                param($Operation, $Prefix, $ResponseTypeName)
                $name = Get-OpenApiGenCommandName -Operation $Operation -NounPrefix $Prefix
                $model = Get-OpenApiGenParameterModel -Operation $Operation -BaseNoun $name.BaseNoun
                $template = (Get-OpenApiGenTemplate -Path (Join-Path -Path $script:TcsOpenApiModuleRoot -ChildPath 'Templates'))['Function.ps1']
                $text = ConvertTo-OpenApiGenFunction -CommandName $name -Operation $Operation -ParameterModel $model -ResponseTypeName $ResponseTypeName -Template $template
                [pscustomobject]@{ Name = $name.Name; Text = $text; Check = (Test-OpenApiGenFunction -Text $text -FunctionName $name.Name) }
            }
        }
        $orderSchema = New-TestSchema -Type object -Required @('item') -Properties ([ordered]@{
                item  = New-TestSchema -Type string
                count = New-TestSchema -Type integer -Format int32
            })
    }

    It 'renders a function that parses and binds' {
        $operation = New-TestOperation -OperationId 'getOrder' -Method GET -Path '/orders/{orderId}' -Parameters @((New-TestParameter -Name 'orderId' -In path))
        $result = ConvertTo-TestFunction -Operation $operation
        $result.Check.IsValid | Should -BeTrue
        $result.Check.ParameterNames | Should -Contain 'OrderId'
        $result.Text | Should -Match '(?m)^function Get-ShopOrder \{$'
        $result.Text | Should -Match "Invoke-OpenApiRequest @tcsRequest"
        $result.Text | Should -Match "\`$script:TcsOpenApiOperations\['getOrder'\]"
        $result.Text | Should -Match "'OrderId' = @\('path', 'orderId'\)"
        $result.Text | Should -Match "\[Alias\('Id'\)\]"
    }

    It 'uses ShouldProcess for <Method> with ConfirmImpact <Impact>' -TestCases @(
        @{ Method = 'POST'; Impact = 'Medium' }, @{ Method = 'PUT'; Impact = 'Medium' }, @{ Method = 'PATCH'; Impact = 'Medium' }, @{ Method = 'DELETE'; Impact = 'High' }
    ) {
        param($Method, $Impact)
        $result = ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'doThing' -Method $Method -Path '/things/{id}' -Parameters @((New-TestParameter -Name 'id' -In path)))
        $result.Text | Should -Match "SupportsShouldProcess = \`$true, ConfirmImpact = '$Impact'"
        $result.Text | Should -Match "ShouldProcess\(\`$tcsTarget, '$Method'\)"
        $result.Check.ParameterNames | Should -Contain 'WhatIf'
    }

    It 'does not use ShouldProcess for <Method>' -TestCases @(@{ Method = 'GET' }, @{ Method = 'HEAD' }, @{ Method = 'OPTIONS' }) {
        param($Method)
        $result = ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'readThing' -Method $Method -Path '/things')
        $result.Text | Should -Not -Match 'ShouldProcess'
        $result.Check.ParameterNames | Should -Not -Contain 'WhatIf'
    }

    It 'uses ShouldProcess for a state-changing verb on GET' {
        (ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'resetCache' -Method GET -Path '/cache')).Text | Should -Match 'SupportsShouldProcess'
    }

    It 'renders a flattened body with two parameter sets' {
        $operation = New-TestOperation -OperationId 'createOrder' -Method POST -Path '/orders' -RequestBody (New-TestRequestBody -Required -Content @((New-TestMediaType -ContentType 'application/json' -Schema $orderSchema)))
        $result = ConvertTo-TestFunction -Operation $operation
        $result.Check.IsValid | Should -BeTrue
        $result.Check.ParameterSets | Should -Be @('Parameters', 'Body')
        $result.Text | Should -Match "DefaultParameterSetName = 'Parameters'"
        $result.Text | Should -Match "if \(\`$PSCmdlet.ParameterSetName -eq 'Body'\)"
        $result.Text | Should -Match "\`$tcsRequest\['ContentType'\] = 'application/json'"
        $result.Text | Should -Match '(?m)^        else \{$'
    }

    It 'sends a flattened optional body only when a body parameter is bound' {
        $operation = New-TestOperation -OperationId 'createOrder' -Method POST -Path '/orders' -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType 'application/json' -Schema $orderSchema)))
        (ConvertTo-TestFunction -Operation $operation).Text | Should -Match "elseif \(\`$tcsValues\['body'\].Count -gt 0\)"
    }

    It 'adds OutputType when the response type is known' {
        (ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'getOrder' -Method GET -Path '/o') -ResponseTypeName 'Shop.Order').Text | Should -Match "\[OutputType\('Shop.Order'\)\]"
        (ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'getOrder' -Method GET -Path '/o')).Text | Should -Not -Match 'OutputType'
    }

    It 'writes help: synopsis, description, parameters, a runnable example, link and deprecation' {
        $operation = New-TestOperation -OperationId 'getOrder' -Method GET -Path '/orders/{orderId}' -Summary 'Gets an order.' -Description 'Returns one order.' -ExternalDocsUrl 'https://docs.example.com/orders' -Deprecated -Parameters @(
            (New-TestParameter -Name 'orderId' -In path -Description 'The order id.' -Example 'o-1'),
            (New-TestParameter -Name 'expand' -In query -Required -Schema (New-TestSchema -Type array -Items (New-TestSchema -Type string)))
        )
        $result = ConvertTo-TestFunction -Operation $operation
        $result.Text | Should -Match '\.SYNOPSIS\s+Gets an order\.'
        $result.Text | Should -Match '\.DESCRIPTION\s+Returns one order\.'
        $result.Text | Should -Match 'This operation is deprecated\.'
        $result.Text | Should -Match '\.PARAMETER OrderId\s+The order id\.'
        $result.Text | Should -Match "\.PARAMETER Expand\s+The 'expand' query parameter\."
        $result.Text | Should -Match '\.PARAMETER Raw'
        $result.Text | Should -Match "\.EXAMPLE\s+Get-ShopOrder -OrderId 'o-1' -Expand @\('example'\)"
        $result.Text | Should -Match '\.LINK\s+https://docs.example.com/orders'
        $example = [regex]::Match($result.Text, '\.EXAMPLE\s+(.+)').Groups[1].Value
        $tokens = $null
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseInput($example, [ref]$tokens, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'uses the method and path when there is no summary or description' {
        (ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'getOrder' -Method GET -Path '/o')).Text | Should -Match '\.SYNOPSIS\s+Calls GET /o\.'
    }

    It 'passes only the locations the operation has' {
        $operation = New-TestOperation -OperationId 'getOrder' -Method GET -Path '/o' -Parameters @((New-TestParameter -Name 'q' -In query), (New-TestParameter -Name 'c' -In cookie))
        $text = (ConvertTo-TestFunction -Operation $operation).Text
        $text | Should -Match "QueryParameters"
        $text | Should -Match "CookieParameters"
        $text | Should -Not -Match "PathParameters"
        $text | Should -Not -Match "HeaderParameters"
    }

    It 'adds a suppression for password parameters and plural-looking nouns' {
        $schema = New-TestSchema -Type object -Properties ([ordered]@{ password = New-TestSchema -Type string })
        $text = (ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'setPassword' -Method PUT -Path '/p' -RequestBody (New-TestRequestBody -Content @((New-TestMediaType -ContentType 'application/json' -Schema $schema))))).Text
        $text | Should -Match "SuppressMessageAttribute\('PSAvoidUsingPlainTextForPassword'"
        (ConvertTo-TestFunction -Operation (New-TestOperation -OperationId 'getMetadata' -Method GET -Path '/m')).Text | Should -Match "SuppressMessageAttribute\('PSUseSingularNouns'"
    }

    It 'escapes quotes from the document in code and help' {
        $operation = New-TestOperation -OperationId "get'Odd" -Method GET -Path "/it's" -Summary 'Has #> in it' -Parameters @((New-TestParameter -Name "o'k" -In query))
        $result = ConvertTo-TestFunction -Operation $operation
        $result.Check.IsValid | Should -BeTrue
        $result.Text | Should -Match "\['get''Odd'\]"
    }
}
