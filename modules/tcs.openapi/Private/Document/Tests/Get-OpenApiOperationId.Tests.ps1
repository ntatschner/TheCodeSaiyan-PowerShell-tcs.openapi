BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../../tcs.openapi.psd1') -Force
}

Describe 'Get-OpenApiOperationId' {
    It 'generates <Expected> for <Method> <Path>' -TestCases @(
        @{ Method = 'GET'; Path = '/pets/{petId}'; Expected = 'getPetsPetId' }
        @{ Method = 'post'; Path = '/pets'; Expected = 'postPets' }
        @{ Method = 'DELETE'; Path = '/users/{user_id}/api-keys/{key-id}'; Expected = 'deleteUsersUserIdApiKeysKeyId' }
        @{ Method = 'GET'; Path = '/v1.2/items'; Expected = 'getV12Items' }
        @{ Method = 'GET'; Path = '/'; Expected = 'getRoot' }
        @{ Method = 'PATCH'; Path = ''; Expected = 'patchRoot' }
    ) {
        InModuleScope tcs.openapi -Parameters @{ Method = $Method; Path = $Path; Expected = $Expected } {
            param($Method, $Path, $Expected)
            Get-OpenApiOperationId -Method $Method -Path $Path | Should -BeExactly $Expected
        }
    }
}
