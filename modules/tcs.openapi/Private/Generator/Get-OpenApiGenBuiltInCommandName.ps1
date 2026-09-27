function Get-OpenApiGenBuiltInCommandName {
    <#
    .SYNOPSIS
        Returns the names of the commands of the core PowerShell modules, which a generated command must
        not shadow.

    .DESCRIPTION
        A fixed list, so the generated names are the same on every machine and edition: the cmdlets and
        functions of Microsoft.PowerShell.Core, .Management, .Utility and .Security in PowerShell 7.4
        (Get-Command -Module ...), plus the commands those modules have only in Windows PowerShell 5.1
        or only on Windows (Get-Service, Get-WmiObject, Get-Acl, Out-GridView, ...). Sorted ordinally.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return [string[]]@(
        'Add-Computer', 'Add-Content', 'Add-History', 'Add-Member', 'Add-PSSnapin', 'Add-Type', 'Checkpoint-Computer',
        'Clear-Content', 'Clear-EventLog', 'Clear-History', 'Clear-Item', 'Clear-ItemProperty', 'Clear-RecycleBin',
        'Clear-Variable', 'Compare-Object', 'Complete-Transaction', 'Connect-PSSession', 'Convert-Path', 'Convert-String',
        'ConvertFrom-Csv', 'ConvertFrom-Json', 'ConvertFrom-Markdown', 'ConvertFrom-SecureString', 'ConvertFrom-String',
        'ConvertFrom-StringData', 'ConvertTo-Csv', 'ConvertTo-Html', 'ConvertTo-Json', 'ConvertTo-SecureString', 'ConvertTo-Xml',
        'Copy-Item', 'Copy-ItemProperty', 'Debug-Job', 'Debug-Process', 'Debug-Runspace', 'Disable-ComputerRestore',
        'Disable-ExperimentalFeature', 'Disable-PSBreakpoint', 'Disable-PSRemoting', 'Disable-PSSessionConfiguration',
        'Disable-RunspaceDebug', 'Disconnect-PSSession', 'Enable-ComputerRestore', 'Enable-ExperimentalFeature',
        'Enable-PSBreakpoint', 'Enable-PSRemoting', 'Enable-PSSessionConfiguration', 'Enable-RunspaceDebug',
        'Enter-PSHostProcess', 'Enter-PSSession', 'Exit-PSHostProcess', 'Exit-PSSession', 'Export-Alias', 'Export-Clixml',
        'Export-Console', 'Export-Csv', 'Export-FormatData', 'Export-ModuleMember', 'Export-PSSession', 'ForEach-Object',
        'Format-Custom', 'Format-Hex', 'Format-List', 'Format-Table', 'Format-Wide', 'Get-Acl', 'Get-Alias',
        'Get-AuthenticodeSignature', 'Get-ChildItem', 'Get-Clipboard', 'Get-CmsMessage', 'Get-Command', 'Get-ComputerInfo',
        'Get-ComputerRestorePoint', 'Get-Content', 'Get-ControlPanelItem', 'Get-Credential', 'Get-Culture', 'Get-Date',
        'Get-Error', 'Get-Event', 'Get-EventLog', 'Get-EventSubscriber', 'Get-ExecutionPolicy', 'Get-ExperimentalFeature',
        'Get-FileHash', 'Get-FormatData', 'Get-Help', 'Get-History', 'Get-Host', 'Get-HotFix', 'Get-Item', 'Get-ItemProperty',
        'Get-ItemPropertyValue', 'Get-Job', 'Get-Location', 'Get-MarkdownOption', 'Get-Member', 'Get-Module', 'Get-PSBreakpoint',
        'Get-PSCallStack', 'Get-PSDrive', 'Get-PSHostProcessInfo', 'Get-PSProvider', 'Get-PSSession', 'Get-PSSessionCapability',
        'Get-PSSessionConfiguration', 'Get-PSSnapin', 'Get-PfxCertificate', 'Get-Process', 'Get-Random', 'Get-Runspace',
        'Get-RunspaceDebug', 'Get-SecureRandom', 'Get-Service', 'Get-TimeZone', 'Get-TraceSource', 'Get-Transaction',
        'Get-TypeData', 'Get-UICulture', 'Get-Unique', 'Get-Uptime', 'Get-Variable', 'Get-Verb', 'Get-WmiObject', 'Group-Object',
        'Import-Alias', 'Import-Clixml', 'Import-Csv', 'Import-LocalizedData', 'Import-Module', 'Import-PSSession',
        'Import-PowerShellDataFile', 'Invoke-Command', 'Invoke-Expression', 'Invoke-History', 'Invoke-Item', 'Invoke-RestMethod',
        'Invoke-WebRequest', 'Invoke-WmiMethod', 'Join-Path', 'Join-String', 'Limit-EventLog', 'Measure-Command', 'Measure-Object',
        'Move-Item', 'Move-ItemProperty', 'New-Alias', 'New-Event', 'New-EventLog', 'New-FileCatalog', 'New-Guid', 'New-Item',
        'New-ItemProperty', 'New-Module', 'New-ModuleManifest', 'New-Object', 'New-PSDrive', 'New-PSRoleCapabilityFile',
        'New-PSSession', 'New-PSSessionConfigurationFile', 'New-PSSessionOption', 'New-PSTransportOption', 'New-Service',
        'New-TemporaryFile', 'New-TimeSpan', 'New-Variable', 'New-WebServiceProxy', 'Out-Default', 'Out-File', 'Out-GridView',
        'Out-Host', 'Out-Null', 'Out-Printer', 'Out-String', 'Pop-Location', 'Protect-CmsMessage', 'Push-Location', 'Read-Host',
        'Receive-Job', 'Receive-PSSession', 'Register-ArgumentCompleter', 'Register-EngineEvent', 'Register-ObjectEvent',
        'Register-PSSessionConfiguration', 'Register-WmiEvent', 'Remove-Alias', 'Remove-Computer', 'Remove-Event',
        'Remove-EventLog', 'Remove-Item', 'Remove-ItemProperty', 'Remove-Job', 'Remove-Module', 'Remove-PSBreakpoint',
        'Remove-PSDrive', 'Remove-PSSession', 'Remove-PSSnapin', 'Remove-Service', 'Remove-TypeData', 'Remove-Variable',
        'Remove-WmiObject', 'Rename-Computer', 'Rename-Item', 'Rename-ItemProperty', 'Reset-ComputerMachinePassword',
        'Resolve-Path', 'Restart-Computer', 'Restart-Service', 'Restore-Computer', 'Resume-Job', 'Resume-Service', 'Save-Help',
        'Select-Object', 'Select-String', 'Select-Xml', 'Send-MailMessage', 'Set-Acl', 'Set-Alias', 'Set-AuthenticodeSignature',
        'Set-Clipboard', 'Set-Content', 'Set-Date', 'Set-ExecutionPolicy', 'Set-Item', 'Set-ItemProperty', 'Set-Location',
        'Set-MarkdownOption', 'Set-PSBreakpoint', 'Set-PSDebug', 'Set-PSSessionConfiguration', 'Set-Service', 'Set-StrictMode', 'Set-TimeZone',
        'Set-TraceSource', 'Set-Variable', 'Set-WmiInstance', 'Show-Command', 'Show-ControlPanelItem', 'Show-EventLog',
        'Show-Markdown', 'Sort-Object', 'Split-Path', 'Start-Job', 'Start-Process', 'Start-Service', 'Start-Sleep',
        'Start-Transaction', 'Stop-Computer', 'Stop-Job', 'Stop-Process', 'Stop-Service', 'Suspend-Job', 'Suspend-Service',
        'Switch-Process', 'Tee-Object', 'Test-ComputerSecureChannel', 'Test-Connection', 'Test-FileCatalog', 'Test-Json',
        'Test-ModuleManifest', 'Test-PSSessionConfigurationFile', 'Test-Path', 'Trace-Command', 'Unblock-File',
        'Undo-Transaction', 'Unprotect-CmsMessage', 'Unregister-Event', 'Unregister-PSSessionConfiguration',
        'Update-FormatData', 'Update-Help', 'Update-List', 'Update-TypeData', 'Use-Transaction', 'Wait-Debugger', 'Wait-Event',
        'Wait-Job', 'Wait-Process', 'Where-Object', 'Write-Debug', 'Write-Error', 'Write-EventLog', 'Write-Host',
        'Write-Information', 'Write-Output', 'Write-Progress', 'Write-Verbose', 'Write-Warning'
    )
}
