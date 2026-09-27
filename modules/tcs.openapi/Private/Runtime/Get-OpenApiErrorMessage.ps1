function Get-OpenApiErrorMessage {
    <#
    .SYNOPSIS
        Builds the message of an HTTP error from problem+json title/detail (or common error shapes), else from the status text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [int]$StatusCode,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ReasonPhrase,

        [Parameter()]
        [AllowNull()]
        [object]$Body,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Method,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Uri
    )

    $status = "$StatusCode"
    if (-not [string]::IsNullOrEmpty($ReasonPhrase)) {
        $status = "$StatusCode ($ReasonPhrase)"
    }
    $detail = $null
    if ($null -ne $Body -and $Body -isnot [string]) {
        $title = [string](Get-OpenApiMember -InputObject $Body -Name 'title')
        $problemDetail = [string](Get-OpenApiMember -InputObject $Body -Name 'detail')
        if ($title -and $problemDetail) {
            $detail = "${title}: $problemDetail"
        }
        elseif ($title -or $problemDetail) {
            $detail = "$title$problemDetail"
        }
        else {
            # Common non-problem shapes: { "message": ... } and { "error": { "message": ... } } / { "error": "..." }
            $message = [string](Get-OpenApiMember -InputObject $Body -Name 'message')
            $errorValue = Get-OpenApiMember -InputObject $Body -Name 'error'
            if ($message) {
                $detail = $message
            }
            elseif ($errorValue -is [string] -and $errorValue) {
                $detail = $errorValue
                $description = [string](Get-OpenApiMember -InputObject $Body -Name 'error_description')
                if ($description) {
                    $detail = "${errorValue}: $description"
                }
            }
            elseif ($null -ne $errorValue) {
                $nested = [string](Get-OpenApiMember -InputObject $errorValue -Name 'message')
                if ($nested) {
                    $detail = $nested
                }
            }
        }
    }
    elseif ($Body -is [string] -and $Body.Length -gt 0 -and $Body.Length -le 500 -and $Body -notmatch '<html') {
        $detail = $Body.Trim()
    }

    $message = "The request $Method $Uri failed with status $status."
    if ($detail) {
        $message = "$message $detail"
    }
    return $message
}
