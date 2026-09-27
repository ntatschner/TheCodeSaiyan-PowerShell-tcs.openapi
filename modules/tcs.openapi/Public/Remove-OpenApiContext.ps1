<#
.SYNOPSIS
    Removes the stored connection of an OpenAPI service.

.DESCRIPTION
    Remove-OpenApiContext clears the context of a service from the current session, with its cached HTTP client
    and OAuth2 tokens. With -Persisted it also deletes the saved settings file and the secrets saved with
    Set-OpenApiContext -Persist; without it, a saved context is loaded again the next time the service is used.

.PARAMETER Service
    The service name.

.PARAMETER Persisted
    Also deletes the context saved for later sessions (settings and secrets).

.INPUTS
    None
    This function does not accept pipeline input.

.OUTPUTS
    None

.EXAMPLE
    Remove-OpenApiContext -Service 'PetStore'

    Clears the PetStore connection from this session.

.EXAMPLE
    Remove-OpenApiContext -Service 'PetStore' -Persisted

    Clears the connection and deletes its saved settings and secrets.

.NOTES
    Author: Nigel Tatschner
    Company: TheCodeSaiyan

.LINK
    Set-OpenApiContext
#>
function Remove-OpenApiContext {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, HelpMessage = 'The service name.')]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
        [string]$Service,

        [Parameter(HelpMessage = 'Also delete the saved settings and secrets.')]
        [switch]$Persisted
    )

    $telemetry = Start-TcsTelemetry
    $failure = $null
    $writtenErrors = New-Object -TypeName System.Collections.ArrayList
    try {
        $store = Get-OpenApiContextStore
        $inSession = $store.ContainsKey($Service)
        $saved = Test-Path -LiteralPath (Get-OpenApiContextSettingPath -Service $Service)
        if (-not $inSession -and -not ($Persisted -and $saved)) {
            if (-not $saved) {
                Write-Error -Message "There is no context for the '$Service' service." -Category ObjectNotFound -TargetObject $Service -ErrorId 'OpenApi.ContextNotFound' -ErrorVariable +writtenErrors
            }
            elseif (-not $Persisted) {
                Write-Verbose -Message "The '$Service' context is saved but not loaded; use -Persisted to delete the saved context."
            }
            return
        }
        $action = 'Remove connection'
        if ($Persisted) {
            $action = 'Remove connection and saved settings and secrets'
        }
        if ($PSCmdlet.ShouldProcess("OpenAPI context '$Service'", $action)) {
            $store.Remove($Service)
            Clear-OpenApiHttpClientCache -Service $Service
            Clear-OpenApiTokenCache -Service $Service
            if ($Persisted) {
                $null = Remove-OpenApiPersistedContext -Service $Service -Confirm:$false
            }
        }
    }
    catch {
        $failure = $_
        throw
    }
    finally {
        # A written "not found" error also makes the run a failed one
        if ($null -eq $failure -and $writtenErrors.Count -gt 0) {
            $failure = $writtenErrors[0]
        }
        Complete-TcsTelemetry -Token $telemetry -ErrorRecord $failure
    }
}
