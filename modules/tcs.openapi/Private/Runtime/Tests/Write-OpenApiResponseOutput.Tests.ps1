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

Describe 'Write-OpenApiResponseOutput' {
    It 'writes array items one by one with the type name' {
        InModuleScope -ModuleName tcs.openapi {
            $items = @(Write-OpenApiResponseOutput -InputObject @([pscustomobject]@{ a = 1 }, [pscustomobject]@{ a = 2 }) -TypeName 'T.Item')
            $items.Count | Should -Be 2
            $items[1].PSObject.TypeNames[0] | Should -Be 'T.Item'
        }
    }

    It 'writes the items property of a page and nothing for an empty page' {
        InModuleScope -ModuleName tcs.openapi {
            $page = [pscustomobject]@{ value = @([pscustomobject]@{ a = 1 }); nextLink = 'x' }
            $items = @(Write-OpenApiResponseOutput -InputObject $page -ItemsProperty 'value' -TypeName 'T.Item')
            $items.Count | Should -Be 1
            $items[0].a | Should -Be 1
            @(Write-OpenApiResponseOutput -InputObject ([pscustomobject]@{ value = @() }) -ItemsProperty 'value').Count | Should -Be 0
        }
    }

    It 'writes the whole object when it has no items property' {
        InModuleScope -ModuleName tcs.openapi {
            $result = Write-OpenApiResponseOutput -InputObject ([pscustomobject]@{ id = 1 }) -ItemsProperty 'value' -TypeName 'T.One'
            $result.id | Should -Be 1
            $result.PSObject.TypeNames[0] | Should -Be 'T.One'
            Write-OpenApiResponseOutput -InputObject $null | Should -BeNullOrEmpty
        }
    }

    It 'writes the value of -UnwrapProperty instead of the whole object' {
        InModuleScope -ModuleName tcs.openapi {
            $result = Write-OpenApiResponseOutput -InputObject ([pscustomobject]@{ data = [pscustomobject]@{ id = 'h1' }; traceId = 't' }) -UnwrapProperty 'data' -TypeName 'T.Host'
            $result.id | Should -Be 'h1'
            $result.PSObject.TypeNames[0] | Should -Be 'T.Host'
            $items = @(Write-OpenApiResponseOutput -InputObject ([pscustomobject]@{ data = @([pscustomobject]@{ id = 1 }, [pscustomobject]@{ id = 2 }) }) -UnwrapProperty 'data')
            $items.id | Should -Be @(1, 2)
            @(Write-OpenApiResponseOutput -InputObject ([pscustomobject]@{ data = $null }) -UnwrapProperty 'data').Count | Should -Be 0
        }
    }

    It 'writes the whole object when the -UnwrapProperty is missing' {
        InModuleScope -ModuleName tcs.openapi {
            $result = Write-OpenApiResponseOutput -InputObject ([pscustomobject]@{ success = $true }) -UnwrapProperty 'data'
            $result.success | Should -BeTrue
            $list = @(Write-OpenApiResponseOutput -InputObject @([pscustomobject]@{ id = 1 }) -UnwrapProperty 'Count')
            $list[0].id | Should -Be 1
        }
    }

    It 'prefers the items property of a page over -UnwrapProperty' {
        InModuleScope -ModuleName tcs.openapi {
            $page = [pscustomobject]@{ data = @([pscustomobject]@{ id = 1 }); nextToken = 'x' }
            $items = @(Write-OpenApiResponseOutput -InputObject $page -ItemsProperty 'data' -UnwrapProperty 'data')
            $items[0].id | Should -Be 1
        }
    }
}
