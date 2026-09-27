@{
    ModuleVersion        = '0.1.0'
    GUID                 = 'fea600e7-039d-4cf2-b288-bbf335757db6'
    Author               = 'Nigel Tatschner'
    CompanyName          = 'TheCodeSaiyan'
    Copyright            = '(c) 2026 Nigel Tatschner. All rights reserved.'
    Description          = 'Generate PowerShell modules from OpenAPI 3.0/3.1 and Swagger 2.0 documents, plus the shared request engine the generated modules use (auth, parameter serialisation, request bodies, retry, paging, errors and downloads).'
    CompatiblePSEditions = @('Desktop', 'Core')
    PowerShellVersion    = '5.1'
    RootModule           = 'tcs.openapi.psm1'
    RequiredModules      = @(
        @{ ModuleName = 'tcs.core'; ModuleVersion = '0.4.0' }
    )
    RequiredAssemblies   = @('System.Net.Http')
    FunctionsToExport    = @(
        'Get-OpenApiContext',
        'Import-OpenApiDocument',
        'Invoke-OpenApiRequest',
        'New-OpenApiModule',
        'Remove-OpenApiContext',
        'Set-OpenApiContext',
        'Test-OpenApiDocument'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()
    PrivateData          = @{
        PSData = @{
            Tags         = @('OpenAPI', 'Swagger', 'REST', 'API', 'CodeGeneration', 'Generator', 'TheCodeSaiyan', 'PSEdition_Desktop', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS')
            LicenseUri   = 'https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.openapi/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/ntatschner/TheCodeSaiyan-PowerShell-tcs.openapi'
            ReleaseNotes = 'See CHANGELOG.md'
        }
    }
}
