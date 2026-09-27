function ConvertTo-OpenApiGenHelp {
    <#
    .SYNOPSIS
        Renders the lines of a comment-based help block (without the comment markers) from an ordered
        list of sections.

    .DESCRIPTION
        -Section is a list of { Keyword, Argument, Text } entries, for example
        @{ Keyword = 'PARAMETER'; Argument = 'PetId'; Text = 'The id of the pet.' }. Keywords are indented
        by -Indent spaces and text by four more. Text from the document is made safe: line endings are
        normalised, tabs become spaces, trailing spaces are removed, comment markers are broken up and a
        line that starts with a help keyword ('.NOTES') gets a space after the dot so it is not read as one.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Section,

        [Parameter()]
        [int]$Indent = 4
    )

    $keywordIndent = ' ' * $Indent
    $textIndent = ' ' * ($Indent + 4)
    $lines = New-Object -TypeName System.Collections.ArrayList
    $keywordPattern = '^\s*\.(SYNOPSIS|DESCRIPTION|PARAMETER|EXAMPLE|INPUTS|OUTPUTS|NOTES|LINK|COMPONENT|ROLE|FUNCTIONALITY|FORWARDHELPTARGETNAME|FORWARDHELPCATEGORY|REMOTEHELPRUNSPACE|EXTERNALHELP)\b'
    foreach ($entry in $Section) {
        if ($lines.Count -gt 0) {
            [void]$lines.Add('')
        }
        $keyword = $keywordIndent + '.' + $entry.Keyword
        if (-not [string]::IsNullOrEmpty([string]$entry.Argument)) {
            $keyword += ' ' + $entry.Argument
        }
        [void]$lines.Add($keyword)
        $text = ([string]$entry.Text).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`t", '    ')
        $text = $text.Replace('#>', '# >').Replace('<#', '< #').Trim("`n")
        $previousBlank = $false
        foreach ($line in $text.Split("`n")) {
            $clean = $line.TrimEnd()
            if ($clean -eq '') {
                if (-not $previousBlank) {
                    [void]$lines.Add('')
                }
                $previousBlank = $true
                continue
            }
            $previousBlank = $false
            if ($clean -match $keywordPattern) {
                # '. NOTES' is not read as a help keyword
                $clean = $clean.Insert($clean.IndexOf('.') + 1, ' ')
            }
            [void]$lines.Add($textIndent + $clean)
        }
    }
    return ($lines -join "`n")
}
