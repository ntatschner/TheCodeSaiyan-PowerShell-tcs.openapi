function Get-OpenApiGenOrdinalSorted {
    <#
    .SYNOPSIS
        Sorts objects by a string key with an ordinal comparison, so the order is the same on every
        machine, culture and PowerShell edition. The sort is stable.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$InputObject,

        [Parameter()]
        [scriptblock]$Key = { [string]$_ }
    )

    $items = @($InputObject | Where-Object -FilterScript { $null -ne $_ })
    if ($items.Count -eq 0) {
        return , @()
    }
    $keys = New-Object -TypeName 'string[]' -ArgumentList $items.Count
    $indexes = New-Object -TypeName 'int[]' -ArgumentList $items.Count
    for ($i = 0; $i -lt $items.Count; $i++) {
        $value = ForEach-Object -InputObject $items[$i] -Process $Key
        # The padded index keeps equal keys in their original order
        $keys[$i] = [string]$value + [char]0 + $i.ToString('D8', [System.Globalization.CultureInfo]::InvariantCulture)
        $indexes[$i] = $i
    }
    [System.Array]::Sort($keys, $indexes, [System.StringComparer]::Ordinal)
    $result = New-Object -TypeName 'object[]' -ArgumentList $items.Count
    for ($i = 0; $i -lt $items.Count; $i++) {
        $result[$i] = $items[$indexes[$i]]
    }
    return , $result
}
