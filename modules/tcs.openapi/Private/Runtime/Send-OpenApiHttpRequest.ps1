function Send-OpenApiHttpRequest {
    <#
    .SYNOPSIS
        Sends one HTTP request with HttpClient and returns a response object whose body is still unread (Message).
    .DESCRIPTION
        The request message and its content are created for this attempt and disposed after the response headers
        arrive. Transport failures are rethrown as the underlying exception (HttpRequestException, TimeoutException).
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Net.Http.HttpClient]$Client,

        [Parameter(Mandatory)]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [Parameter()]
        [AllowNull()]
        [System.Collections.IDictionary]$Header,

        [Parameter()]
        [AllowNull()]
        [scriptblock]$ContentFactory,

        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$SensitiveName
    )

    $request = New-Object System.Net.Http.HttpRequestMessage -ArgumentList (New-Object System.Net.Http.HttpMethod -ArgumentList $Method.ToUpperInvariant()), ([uri]$Uri)
    try {
        if ($null -ne $ContentFactory) {
            $request.Content = & $ContentFactory
        }
        if ($null -ne $Header) {
            foreach ($key in $Header.Keys) {
                $name = [string]$key
                $value = [string]$Header[$key]
                if ($name -eq 'Content-Type') {
                    if ($null -ne $request.Content) {
                        $request.Content.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($value)
                    }
                    continue
                }
                if (-not $request.Headers.TryAddWithoutValidation($name, $value)) {
                    if ($null -ne $request.Content) {
                        [void]$request.Content.Headers.Remove($name)
                        [void]$request.Content.Headers.TryAddWithoutValidation($name, $value)
                    }
                }
            }
        }

        $displayUri = Get-OpenApiRedactedUri -Uri $Uri -SensitiveName $SensitiveName
        Write-Verbose -Message ('{0} {1}' -f $request.Method.Method, $displayUri)
        if ($DebugPreference -ne 'SilentlyContinue') {
            $headerLog = [ordered]@{}
            foreach ($pair in $request.Headers) {
                $headerLog[$pair.Key] = @($pair.Value)
            }
            if ($null -ne $request.Content) {
                foreach ($pair in $request.Content.Headers) {
                    $headerLog[$pair.Key] = @($pair.Value)
                }
            }
            Write-Debug -Message ("Request headers:" + [Environment]::NewLine + (Format-OpenApiHeaderLog -Header $headerLog -SensitiveName $SensitiveName))
            if ($null -ne $request.Content) {
                Write-Debug -Message ('Request body: ' + (Get-OpenApiBodyLogText -Content $request.Content))
            }
        }

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $message = $Client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        }
        catch {
            $failure = $_.Exception
            while (($failure -is [System.Management.Automation.MethodInvocationException] -or $failure -is [System.AggregateException]) -and $null -ne $failure.InnerException) {
                $failure = $failure.InnerException
            }
            if ($failure -is [System.Threading.Tasks.TaskCanceledException] -or $failure -is [System.OperationCanceledException]) {
                $failure = New-Object System.TimeoutException -ArgumentList "The request $($request.Method.Method) $displayUri timed out after $([int]$Client.Timeout.TotalSeconds) seconds.", $failure
            }
            Write-Verbose -Message "$($request.Method.Method) $displayUri failed: $($failure.Message)"
            throw $failure
        }
        $stopwatch.Stop()

        $headers = ConvertFrom-OpenApiHttpHeader -Response $message
        $contentType = $null
        if ($null -ne $message.Content -and $null -ne $message.Content.Headers.ContentType) {
            $contentType = $message.Content.Headers.ContentType.ToString()
        }
        Write-Verbose -Message ('{0} {1} -> {2} {3} ({4} ms)' -f $request.Method.Method, $displayUri, [int]$message.StatusCode, $message.ReasonPhrase, $stopwatch.ElapsedMilliseconds)
        if ($DebugPreference -ne 'SilentlyContinue') {
            Write-Debug -Message ("Response headers:" + [Environment]::NewLine + (Format-OpenApiHeaderLog -Header $headers -SensitiveName $SensitiveName))
        }
        return [pscustomobject]@{
            PSTypeName   = 'Tcs.OpenApi.HttpResponse'
            Method       = $request.Method.Method
            Uri          = $Uri
            StatusCode   = [int]$message.StatusCode
            ReasonPhrase = $message.ReasonPhrase
            Headers      = $headers
            ContentType  = $contentType
            Message      = $message
            Body         = $null
        }
    }
    finally {
        $request.Dispose()
    }
}
