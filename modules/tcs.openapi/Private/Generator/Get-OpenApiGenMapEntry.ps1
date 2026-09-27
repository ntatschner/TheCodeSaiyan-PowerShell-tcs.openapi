function Get-OpenApiGenMapEntry {
    <#
    .SYNOPSIS
        Lists the entries of a document-model map (dictionary or PSCustomObject) in a deterministic order.

    .DESCRIPTION
        Ordered dictionaries and PSCustomObjects keep their own order. Other dictionaries (such as
        Hashtable, whose order changes between processes) are sorted by key with an ordinal comparison.
        Returns one { Key, Value } object per entry; nothing for $null.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$Map
    )

    if ($null -eq $Map) {
        return
    }
    if ($Map -is [System.Collections.IDictionary]) {
        $keys = @($Map.Keys | ForEach-Object -Process { [string]$_ })
        if (-not ($Map -is [System.Collections.Specialized.OrderedDictionary])) {
            $sorted = [string[]]$keys
            [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
            $keys = $sorted
        }
        foreach ($key in $keys) {
            [pscustomobject]@{ Key = $key; Value = $Map[$key] }
        }
        return
    }
    if ($Map -is [System.Management.Automation.PSCustomObject]) {
        foreach ($property in $Map.PSObject.Properties) {
            [pscustomobject]@{ Key = $property.Name; Value = $property.Value }
        }
    }
}
