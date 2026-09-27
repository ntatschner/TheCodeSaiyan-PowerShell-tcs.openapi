<#
.SYNOPSIS
    A small HTTP server for end-to-end tests: System.Net.HttpListener on the loopback address, served from a
    background runspace, recording every request and answering with scripted responses.

.DESCRIPTION
    Dot-source this file, then call Start-TestHttpServer. Responses are taken, in this order, from:
      1. -Responses: a queue of response hashtables, each used once;
      2. -Routes: a hashtable keyed by 'METHOD /path' (or '/path' for any method) whose values are response
         hashtables or script blocks (param($Request)) returning one;
      3. -Handler: a script block (param($Request)) returning a response hashtable;
      4. otherwise 404.
    A response hashtable has StatusCode (default 200), Headers (hashtable), Body (string, byte[] or an object that
    is sent as JSON), ContentType and DelayMilliseconds. The text '{{BaseUri}}' in string bodies and header values
    is replaced by the server's base URI.

    Script blocks run in the server's runspace, so they cannot see the test's variables; they are passed as text.
    Works on Windows PowerShell 5.1 and PowerShell 7.
#>

function Start-TestHttpServer {
    <#
    .SYNOPSIS
        Starts the test HTTP server and returns { BaseUri, Requests, Stop() }.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper: starts a loopback listener that the test stops.')]
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [object[]]$Responses,

        [Parameter()]
        [hashtable]$Routes,

        [Parameter()]
        [scriptblock]$Handler
    )

    $isWindowsOs = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    $listener = $null
    $baseUri = $null
    $lastError = $null
    for ($try = 0; $try -lt 10 -and $null -eq $listener; $try++) {
        # Ask the OS for a free port, then listen on it
        $probe = New-Object System.Net.Sockets.TcpListener -ArgumentList ([System.Net.IPAddress]::Loopback), 0
        $probe.Start()
        $port = ([System.Net.IPEndPoint]$probe.LocalEndpoint).Port
        $probe.Stop()
        $hostNames = @('127.0.0.1')
        if ($isWindowsOs) {
            # HTTP.sys lets non-administrators listen on 'localhost' only
            $hostNames = @('127.0.0.1', 'localhost')
        }
        foreach ($hostName in $hostNames) {
            $candidate = New-Object System.Net.HttpListener
            $candidate.Prefixes.Add("http://${hostName}:$port/")
            try {
                $candidate.Start()
                $listener = $candidate
                $baseUri = "http://${hostName}:$port"
                break
            }
            catch {
                $lastError = $_
                $candidate.Close()
            }
        }
    }
    if ($null -eq $listener) {
        throw "The test HTTP server could not start: $lastError"
    }

    $requests = [System.Collections.ArrayList]::Synchronized((New-Object System.Collections.ArrayList))
    $queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    foreach ($response in @($Responses)) {
        if ($null -ne $response) {
            $queue.Enqueue((ConvertTo-TestHttpServerResponse -Response $response))
        }
    }
    $routeTable = @{}
    if ($null -ne $Routes) {
        foreach ($key in $Routes.Keys) {
            $routeTable[[string]$key] = ConvertTo-TestHttpServerResponse -Response $Routes[$key]
        }
    }
    $handlerText = $null
    if ($null -ne $Handler) {
        $handlerText = $Handler.ToString()
    }

    $serverScript = {
        param($Listener, $Requests, $Queue, $RouteTable, $HandlerText, $BaseUri)

        function ConvertTo-ServedResponse {
            param($Spec, $Request)
            if ($Spec -is [hashtable] -and $Spec.ContainsKey('ScriptText')) {
                $block = [scriptblock]::Create($Spec['ScriptText'])
                $Spec = & $block $Request
            }
            return $Spec
        }

        $handlerBlock = $null
        if ($HandlerText) {
            $handlerBlock = [scriptblock]::Create($HandlerText)
        }
        $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
        while ($Listener.IsListening) {
            try {
                $context = $Listener.GetContext()
            }
            catch {
                break
            }
            try {
                $httpRequest = $context.Request
                $memory = New-Object System.IO.MemoryStream
                if ($httpRequest.HasEntityBody) {
                    $httpRequest.InputStream.CopyTo($memory)
                }
                $bytes = $memory.ToArray()
                $headers = @{}
                foreach ($name in $httpRequest.Headers.AllKeys) {
                    $headers[$name] = $httpRequest.Headers[$name]
                }
                $record = [pscustomobject]@{
                    Method      = $httpRequest.HttpMethod
                    Url         = $httpRequest.Url.AbsoluteUri
                    RawUrl      = $httpRequest.RawUrl
                    Path        = $httpRequest.Url.AbsolutePath
                    Query       = $httpRequest.Url.Query
                    Headers     = $headers
                    ContentType = $httpRequest.ContentType
                    BodyBytes   = $bytes
                    Body        = $utf8.GetString($bytes)
                    ReceivedAt  = [datetime]::UtcNow
                }
                [void]$Requests.Add($record)

                $spec = $null
                $queued = $null
                if ($Queue.TryDequeue([ref]$queued)) {
                    $spec = ConvertTo-ServedResponse -Spec $queued -Request $record
                }
                elseif ($RouteTable.ContainsKey("$($record.Method) $($record.Path)")) {
                    $spec = ConvertTo-ServedResponse -Spec $RouteTable["$($record.Method) $($record.Path)"] -Request $record
                }
                elseif ($RouteTable.ContainsKey($record.Path)) {
                    $spec = ConvertTo-ServedResponse -Spec $RouteTable[$record.Path] -Request $record
                }
                elseif ($null -ne $handlerBlock) {
                    $spec = & $handlerBlock $record
                }
                if ($null -eq $spec) {
                    $spec = @{ StatusCode = 404; Body = 'No scripted response.'; ContentType = 'text/plain' }
                }

                if ($spec['DelayMilliseconds']) {
                    Start-Sleep -Milliseconds ([int]$spec['DelayMilliseconds'])
                }
                $status = 200
                if ($spec['StatusCode']) {
                    $status = [int]$spec['StatusCode']
                }
                $body = $spec['Body']
                $contentType = $spec['ContentType']
                $payload = [byte[]]@()
                if ($body -is [byte[]]) {
                    $payload = $body
                }
                elseif ($body -is [string]) {
                    $payload = $utf8.GetBytes($body.Replace('{{BaseUri}}', $BaseUri))
                }
                elseif ($null -ne $body) {
                    $payload = $utf8.GetBytes((ConvertTo-Json -InputObject $body -Depth 20 -Compress).Replace('{{BaseUri}}', $BaseUri))
                    if (-not $contentType) {
                        $contentType = 'application/json'
                    }
                }
                $httpResponse = $context.Response
                $httpResponse.StatusCode = $status
                if ($contentType) {
                    $httpResponse.ContentType = $contentType
                }
                if ($spec['Headers']) {
                    foreach ($name in $spec['Headers'].Keys) {
                        $httpResponse.Headers.Add([string]$name, ([string]$spec['Headers'][$name]).Replace('{{BaseUri}}', $BaseUri))
                    }
                }
                if ($payload.Length -gt 0) {
                    $httpResponse.ContentLength64 = $payload.Length
                    $httpResponse.OutputStream.Write($payload, 0, $payload.Length)
                }
                $httpResponse.OutputStream.Close()
            }
            catch {
                try {
                    $context.Response.StatusCode = 500
                    $context.Response.Close()
                }
                catch {
                    $null = $_
                }
            }
        }
    }

    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $powershell = [powershell]::Create()
    $powershell.Runspace = $runspace
    [void]$powershell.AddScript($serverScript.ToString())
    [void]$powershell.AddArgument($listener).AddArgument($requests).AddArgument($queue).AddArgument($routeTable).AddArgument($handlerText).AddArgument($baseUri)
    $handle = $powershell.BeginInvoke()

    $server = [pscustomobject]@{
        PSTypeName  = 'Tcs.TestHttpServer'
        BaseUri     = $baseUri
        Requests    = $requests
        Listener    = $listener
        PowerShell  = $powershell
        Runspace    = $runspace
        AsyncHandle = $handle
        Queue       = $queue
    }
    $server | Add-Member -MemberType ScriptMethod -Name Stop -Value {
        try {
            $this.Listener.Stop()
            $this.Listener.Close()
        }
        catch {
            $null = $_
        }
        try {
            [void]$this.AsyncHandle.AsyncWaitHandle.WaitOne(5000)
            $this.PowerShell.Stop()
            $this.PowerShell.Dispose()
            $this.Runspace.Dispose()
        }
        catch {
            $null = $_
        }
    }
    $server | Add-Member -MemberType ScriptMethod -Name Enqueue -Value {
        param($Response)
        $this.Queue.Enqueue((ConvertTo-TestHttpServerResponse -Response $Response))
    }
    return $server
}

function ConvertTo-TestHttpServerResponse {
    <#
    .SYNOPSIS
        Copies a response definition into a form that can cross into the server runspace (script blocks as text).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    if ($Response -is [scriptblock]) {
        return @{ ScriptText = $Response.ToString() }
    }
    $copy = @{}
    foreach ($key in $Response.Keys) {
        $copy[$key] = $Response[$key]
    }
    return $copy
}
