BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
    # Windows PowerShell 5.1 does not load System.Net.Http by default
    Add-Type -AssemblyName 'System.Net.Http'
}

AfterAll {
    Remove-Module -Name tcs.openapi -Force -ErrorAction SilentlyContinue
}

Describe 'Add-OpenApiTypeName' {
    It 'inserts the type name first on a PSCustomObject once' {
        InModuleScope -ModuleName tcs.openapi {
            $item = [pscustomobject]@{ id = 1 }
            $result = Add-OpenApiTypeName -InputObject $item -TypeName 'Svc.Pet'
            $result.PSObject.TypeNames[0] | Should -Be 'Svc.Pet'
            $null = Add-OpenApiTypeName -InputObject $item -TypeName 'Svc.Pet'
            @($item.PSObject.TypeNames | Where-Object -FilterScript { $_ -eq 'Svc.Pet' }).Count | Should -Be 1
        }
    }

    It 'passes other values through unchanged' {
        InModuleScope -ModuleName tcs.openapi {
            Add-OpenApiTypeName -InputObject 5 -TypeName 'Svc.Pet' | Should -Be 5
            Add-OpenApiTypeName -InputObject $null -TypeName 'Svc.Pet' | Should -BeNullOrEmpty
            $item = [pscustomobject]@{ id = 1 }
            (Add-OpenApiTypeName -InputObject $item -TypeName '').PSObject.TypeNames[0] | Should -Be 'System.Management.Automation.PSCustomObject'
        }
    }
}
