BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # A caller in another module, like a generated command
    New-Module -Name 'TcsCallerPreferenceTest' -ScriptBlock {
        function Test-CallerPreference {
            [CmdletBinding()]
            param()
            & (Get-Module -Name tcs.openapi) { param($Caller) Get-OpenApiCallerPreference -Cmdlet $Caller } $PSCmdlet
        }
    } | Import-Module
}

AfterAll {
    Remove-Module -Name 'TcsCallerPreferenceTest' -Force -ErrorAction SilentlyContinue
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Get-OpenApiCallerPreference' {
    It 'reads -Verbose and -Debug given to the calling command' {
        $result = Test-CallerPreference -Verbose -Debug
        $result['VerbosePreference'] | Should -Be 'Continue'
        $result['DebugPreference'] | Should -Be 'Continue'
    }

    It 'reads -Verbose:$false and -WarningAction' {
        $result = Test-CallerPreference -Verbose:$false -WarningAction Ignore
        $result['VerbosePreference'] | Should -Be 'SilentlyContinue'
        $result['WarningPreference'] | Should -Be 'Ignore'
    }

    It 'falls back to the preference visible to the calling module' {
        $old = $global:VerbosePreference
        try {
            $global:VerbosePreference = 'Continue'
            (Test-CallerPreference)['VerbosePreference'] | Should -Be 'Continue'
            $global:VerbosePreference = 'SilentlyContinue'
            (Test-CallerPreference)['VerbosePreference'] | Should -Be 'SilentlyContinue'
        }
        finally {
            $global:VerbosePreference = $old
        }
    }
}
