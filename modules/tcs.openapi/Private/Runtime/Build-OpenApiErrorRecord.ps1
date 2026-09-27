function Build-OpenApiErrorRecord {
    <#
    .SYNOPSIS
        Creates the ErrorRecord for a failed request: FullyQualifiedErrorId OpenApi.<Service>.<StatusCode|Kind>, a category from the status and a TargetObject describing the request.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Http')]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory)]
        [string]$Service,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$OperationId,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Method,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Uri,

        [Parameter(Mandatory, ParameterSetName = 'Http')]
        [pscustomobject]$Response,

        [Parameter(ParameterSetName = 'Http')]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$SensitiveName,

        [Parameter(Mandatory, ParameterSetName = 'Exception')]
        [System.Exception]$Exception,

        [Parameter(Mandatory, ParameterSetName = 'Exception')]
        [string]$Kind,

        [Parameter(ParameterSetName = 'Exception')]
        [System.Management.Automation.ErrorCategory]$Category = [System.Management.Automation.ErrorCategory]::NotSpecified
    )

    $displayUri = Get-OpenApiRedactedUri -Uri $Uri -SensitiveName $SensitiveName
    if ($PSCmdlet.ParameterSetName -eq 'Exception') {
        $target = [pscustomobject]@{
            PSTypeName  = 'Tcs.OpenApi.ErrorTarget'
            Method      = $Method
            Uri         = $displayUri
            StatusCode  = $null
            Headers     = $null
            Body        = $null
            OperationId = $OperationId
        }
        return (New-Object System.Management.Automation.ErrorRecord -ArgumentList $Exception, "OpenApi.$Service.$Kind", $Category, $target)
    }

    $bytes = Read-OpenApiResponseBody -Response $Response
    $text = ConvertTo-OpenApiResponseText -Bytes $bytes -ContentType $Response.ContentType
    $body = ConvertFrom-OpenApiErrorBody -Text $text -ContentType $Response.ContentType
    $message = Get-OpenApiErrorMessage -StatusCode $Response.StatusCode -ReasonPhrase $Response.ReasonPhrase -Body $body -Method $Method -Uri $displayUri
    $exception = New-Object System.Net.Http.HttpRequestException -ArgumentList $message
    $target = [pscustomobject]@{
        PSTypeName  = 'Tcs.OpenApi.ErrorTarget'
        Method      = $Method
        Uri         = $displayUri
        StatusCode  = $Response.StatusCode
        Headers     = $Response.Headers
        Body        = $body
        OperationId = $OperationId
    }
    $category = Get-OpenApiErrorCategory -StatusCode $Response.StatusCode
    return (New-Object System.Management.Automation.ErrorRecord -ArgumentList $exception, "OpenApi.$Service.$($Response.StatusCode)", $category, $target)
}
