BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Get-OpenApiErrorCategory' {
    It 'maps <StatusCode> to <Category>' -ForEach @(
        @{ StatusCode = 400; Category = 'InvalidArgument' }
        @{ StatusCode = 401; Category = 'AuthenticationError' }
        @{ StatusCode = 403; Category = 'PermissionDenied' }
        @{ StatusCode = 404; Category = 'ObjectNotFound' }
        @{ StatusCode = 408; Category = 'OperationTimeout' }
        @{ StatusCode = 409; Category = 'ResourceExists' }
        @{ StatusCode = 418; Category = 'InvalidOperation' }
        @{ StatusCode = 422; Category = 'InvalidData' }
        @{ StatusCode = 429; Category = 'LimitsExceeded' }
        @{ StatusCode = 500; Category = 'InvalidResult' }
        @{ StatusCode = 501; Category = 'NotImplemented' }
        @{ StatusCode = 503; Category = 'ResourceUnavailable' }
        @{ StatusCode = 504; Category = 'OperationTimeout' }
        @{ StatusCode = 599; Category = 'NotSpecified' }
    ) {
        InModuleScope -ModuleName tcs.openapi -Parameters @{ StatusCode = $StatusCode; Category = $Category } {
            Get-OpenApiErrorCategory -StatusCode $StatusCode | Should -Be ([System.Management.Automation.ErrorCategory]$Category)
        }
    }
}
