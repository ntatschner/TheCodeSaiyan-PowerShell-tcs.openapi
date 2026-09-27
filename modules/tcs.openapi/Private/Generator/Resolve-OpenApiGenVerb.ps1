function Resolve-OpenApiGenVerb {
    <#
    .SYNOPSIS
        Maps the first word of an operationId to an approved verb, or returns the default verb for an
        HTTP method.

    .DESCRIPTION
        With -Word: returns { Verb, IsList } when the word is a known verb word, otherwise nothing.
        get/fetch/retrieve/read/show/describe -> Get; list/find/search/query -> Get with IsList;
        create/add/new/post -> New; update/patch/modify -> Update, set/put/replace -> Set, except that
        PUT always gives Set and PATCH always gives Update; delete/remove/destroy -> Remove;
        validate/check/verify -> Test; execute/run/trigger -> Invoke; other words that are approved
        verbs in a fixed list (start, stop, enable, import, sync, grant, ...) -> that verb.
        With -Method only: GET Get, POST New, PUT Set, PATCH Update, DELETE Remove, HEAD Test,
        OPTIONS and TRACE Get.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Word,

        [Parameter(Mandatory = $true)]
        [string]$Method
    )

    $upperMethod = $Method.ToUpperInvariant()
    if ([string]::IsNullOrEmpty($Word)) {
        $defaults = @{
            'GET'     = 'Get'
            'POST'    = 'New'
            'PUT'     = 'Set'
            'PATCH'   = 'Update'
            'DELETE'  = 'Remove'
            'HEAD'    = 'Test'
            'OPTIONS' = 'Get'
            'TRACE'   = 'Get'
        }
        $verb = 'Invoke'
        if ($defaults.ContainsKey($upperMethod)) {
            $verb = $defaults[$upperMethod]
        }
        return [pscustomobject]@{ Verb = $verb; IsList = $false }
    }

    $lower = $Word.ToLowerInvariant()
    $groups = @{
        'get'      = 'Get'
        'fetch'    = 'Get'
        'retrieve' = 'Get'
        'read'     = 'Get'
        'show'     = 'Get'
        'describe' = 'Get'
        'create'   = 'New'
        'add'      = 'New'
        'new'      = 'New'
        'post'     = 'New'
        'delete'   = 'Remove'
        'remove'   = 'Remove'
        'destroy'  = 'Remove'
        'validate' = 'Test'
        'check'    = 'Test'
        'verify'   = 'Test'
        'execute'  = 'Invoke'
        'run'      = 'Invoke'
        'trigger'  = 'Invoke'
    }
    if (@('list', 'find', 'search', 'query') -contains $lower) {
        return [pscustomobject]@{ Verb = 'Get'; IsList = $true }
    }
    if (@('update', 'patch', 'modify', 'set', 'put', 'replace') -contains $lower) {
        if ($upperMethod -eq 'PUT') {
            return [pscustomobject]@{ Verb = 'Set'; IsList = $false }
        }
        if ($upperMethod -eq 'PATCH' -or @('update', 'patch', 'modify') -contains $lower) {
            return [pscustomobject]@{ Verb = 'Update'; IsList = $false }
        }
        return [pscustomobject]@{ Verb = 'Set'; IsList = $false }
    }
    if ($groups.ContainsKey($lower)) {
        return [pscustomobject]@{ Verb = $groups[$lower]; IsList = $false }
    }
    $matching = @(
        'Approve', 'Block', 'Clear', 'Complete', 'Confirm', 'Connect', 'Copy', 'Deny', 'Disable', 'Disconnect',
        'Enable', 'Export', 'Grant', 'Import', 'Install', 'Invoke', 'Lock', 'Merge', 'Move', 'Publish',
        'Register', 'Rename', 'Reset', 'Restart', 'Restore', 'Resume', 'Revoke', 'Send', 'Start', 'Stop',
        'Submit', 'Suspend', 'Sync', 'Test', 'Unblock', 'Uninstall', 'Unlock', 'Unpublish', 'Unregister'
    )
    foreach ($verb in $matching) {
        if ($verb.ToLowerInvariant() -eq $lower) {
            return [pscustomobject]@{ Verb = $verb; IsList = $false }
        }
    }
}
