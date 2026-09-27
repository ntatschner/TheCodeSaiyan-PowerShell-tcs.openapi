function Test-OpenApiGenFunction {
    <#
    .SYNOPSIS
        Checks that generated source parses and that the function it defines binds.

    .DESCRIPTION
        Parses the text with the PowerShell parser (no parse errors, exactly one top-level function
        with the expected name), then defines the function in a throwaway child scope and reads its
        parameter metadata and syntax, which builds every attribute (a duplicate alias, a bad
        ValidateRange or an invalid parameter set fails here). Nothing is run and nothing leaks out
        of the child scope. Returns { IsValid, Errors, ParameterNames, ParameterSets, Syntax }.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$FunctionName
    )

    $errors = New-Object -TypeName System.Collections.ArrayList
    $parameterNames = @()
    $parameterSets = @()
    $syntax = $null

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$parseErrors)
    foreach ($parseError in @($parseErrors)) {
        [void]$errors.Add("Parse error at line $($parseError.Extent.StartLineNumber): $($parseError.Message)")
    }
    if ($errors.Count -eq 0) {
        $functions = @($ast.EndBlock.Statements | Where-Object -FilterScript { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] })
        $otherStatements = @($ast.EndBlock.Statements | Where-Object -FilterScript { -not ($_ -is [System.Management.Automation.Language.FunctionDefinitionAst]) })
        if ($functions.Count -ne 1 -or $functions[0].Name -ne $FunctionName -or $otherStatements.Count -gt 0) {
            [void]$errors.Add("The text must define exactly one function named '$FunctionName' and nothing else.")
        }
    }
    if ($errors.Count -eq 0) {
        $bindResult = & {
            # Child scope: the function disappears when the script block ends
            try {
                . ([scriptblock]::Create($Text))
                # Module-qualified: the generated function may be named like one of these cmdlets
                $command = Microsoft.PowerShell.Management\Get-Item -LiteralPath "function:$FunctionName" -ErrorAction Stop
                $names = @($command.Parameters.Keys)
                $sets = @(foreach ($set in $command.ParameterSets) { $set.Name })
                $usage = (Microsoft.PowerShell.Core\Get-Command -Name $FunctionName -CommandType Function -Syntax -ErrorAction Stop | Microsoft.PowerShell.Utility\Out-String).Trim()
                [pscustomobject]@{ Error = $null; Names = $names; Sets = $sets; Syntax = $usage }
            }
            catch {
                [pscustomobject]@{ Error = $_.Exception.Message; Names = @(); Sets = @(); Syntax = $null }
            }
        }
        if ($null -ne $bindResult.Error) {
            [void]$errors.Add("Bind check failed: $($bindResult.Error)")
        }
        else {
            $parameterNames = $bindResult.Names
            $parameterSets = $bindResult.Sets
            $syntax = $bindResult.Syntax
        }
    }

    return [pscustomobject]@{
        IsValid        = ($errors.Count -eq 0)
        Errors         = $errors.ToArray()
        ParameterNames = $parameterNames
        ParameterSets  = $parameterSets
        Syntax         = $syntax
    }
}
