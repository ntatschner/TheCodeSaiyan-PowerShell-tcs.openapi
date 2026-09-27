function Get-OpenApiCallerPreference {
    <#
    .SYNOPSIS
        Returns the Verbose, Debug and Warning preferences of the command that called the engine.

    .DESCRIPTION
        Preference variables do not cross module boundaries, and $Cmdlet.SessionState resolves variables
        in the calling module's script scope rather than in the calling function's scope, so -Verbose,
        -Debug and -WarningAction given to a generated command are read from its bound parameters.
        Without them, the value visible in the calling module's session state is used. Returns a
        hashtable keyed by preference variable name (only the preferences that have a value).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.PSCmdlet]$Cmdlet
    )

    $result = @{}
    $bound = $Cmdlet.MyInvocation.BoundParameters
    $switches = @{ VerbosePreference = 'Verbose'; DebugPreference = 'Debug' }
    foreach ($preference in @('VerbosePreference', 'DebugPreference', 'WarningPreference')) {
        $value = $null
        if ($switches.ContainsKey($preference) -and $bound.ContainsKey($switches[$preference])) {
            $value = 'SilentlyContinue'
            if ([bool]$bound[$switches[$preference]]) {
                $value = 'Continue'
            }
        }
        elseif ($preference -eq 'WarningPreference' -and $bound.ContainsKey('WarningAction')) {
            $value = $bound['WarningAction']
        }
        else {
            $value = $Cmdlet.SessionState.PSVariable.GetValue($preference)
        }
        if ($null -ne $value) {
            $result[$preference] = [System.Management.Automation.ActionPreference]$value
        }
    }
    return $result
}
