function ConvertTo-OpenApiGenHelpText {
    <#
    .SYNOPSIS
        Turns a CommonMark/HTML description from an OpenAPI document into plain help text that also
        passes through PlatyPS into MDX (Docusaurus, Astro Starlight) unchanged.

    .DESCRIPTION
        Fenced code blocks and inline code spans are kept as they are. In the rest:
        - HTML comments are removed; <code>x</code> becomes `x`; <br> a line break; <p>, headings and
          lists paragraph breaks and '- ' items; <a href="u">t</a> 't (u)'; other tags are removed;
          &lt; &gt; &quot; &#39; &apos; &nbsp; and &amp; are decoded.
        - Markdown links and images become 'text (url)' (just the url when both are the same),
          <https://...> autolinks the url, **bold**, __bold__, *emphasis* and ~~strike~~ lose their
          markers, '#' heading markers and '>' quote markers are removed, '* ' and '+ ' list items
          become '- ', and backslash escapes are resolved.
        - A word that holds '<', '{' or '}' (after the above) is put in backticks, because MDX reads
          '<' as JSX and '{' as an expression, and a line that starts with 'import ' or 'export '
          (read as ESM by MDX) gets a capital letter.
        Line endings become LF, trailing spaces are removed and more than one blank line becomes one.
        -SingleLine joins the lines with spaces (for a synopsis).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter()]
        [switch]$SingleLine
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }
    $source = $Text.Replace("`r`n", "`n").Replace("`r", "`n").Replace("`t", '    ')

    # Fenced code blocks stay as they are
    $segments = New-Object -TypeName System.Collections.ArrayList
    $current = New-Object -TypeName System.Collections.ArrayList
    $fence = $null
    foreach ($line in $source.Split("`n")) {
        if ($null -eq $fence) {
            $open = [regex]::Match($line, '^\s{0,3}(```+|~~~+)')
            if ($open.Success) {
                if ($current.Count -gt 0) {
                    [void]$segments.Add([pscustomobject]@{ Code = $false; Text = ($current -join "`n") })
                    $current.Clear()
                }
                $fence = $open.Groups[1].Value
                [void]$current.Add($line.Trim())
                continue
            }
            [void]$current.Add($line)
            continue
        }
        [void]$current.Add($line)
        if ($line.Trim().StartsWith($fence)) {
            [void]$segments.Add([pscustomobject]@{ Code = $true; Text = ($current -join "`n") })
            $current.Clear()
            $fence = $null
        }
    }
    if ($current.Count -gt 0) {
        if ($null -ne $fence) {
            # An unclosed fence: close it so the rest of the page is not read as code
            [void]$current.Add($fence)
        }
        [void]$segments.Add([pscustomobject]@{ Code = ($null -ne $fence); Text = ($current -join "`n") })
    }

    $parts = foreach ($segment in $segments) {
        if ($segment.Code) {
            "`n" + $segment.Text + "`n"
            continue
        }
        $prose = [regex]::Replace($segment.Text, '<!--[\s\S]*?-->', '')
        $prose = [regex]::Replace($prose, '(?is)<code\b[^>]*>(.*?)</code>', {
                param($Match)
                '`' + $Match.Groups[1].Value.Replace('`', '') + '`'
            })
        # Inline code spans stay as they are
        $pieces = [regex]::Split($prose, '(`+[^`]+?`+)')
        $converted = foreach ($piece in $pieces) {
            if ($piece -match '^`+[^`]+?`+$') {
                $piece
                continue
            }
            # Backslash escapes: hide the escaped character until the markers are handled
            $t = [regex]::Replace($piece, '\\([\\`*_{}\[\]()#+\-.!<>|~])', {
                    param($Match)
                    [string][char](0xE000 + [int][char]$Match.Groups[1].Value)
                })
            $t = [regex]::Replace($t, '<((?:https?|mailto):[^<>\s]+)>', '$1')
            $t = [regex]::Replace($t, '(?is)<a\b[^>]*\bhref\s*=\s*["'']([^"'']*)["''][^>]*>(.*?)</a>', {
                    param($Match)
                    $label = $Match.Groups[2].Value.Trim()
                    $url = $Match.Groups[1].Value.Trim()
                    if ($label -eq '' -or $label -eq $url) { $url } else { "$label ($url)" }
                })
            $t = [regex]::Replace($t, '(?i)<br\s*/?>', "`n")
            $t = [regex]::Replace($t, '(?i)</?(p|div|h[1-6]|table|tr)\b[^>]*>', "`n`n")
            $t = [regex]::Replace($t, '(?i)<li\b[^>]*>', "`n- ")
            $t = [regex]::Replace($t, '(?i)</?(ul|ol)\b[^>]*>', "`n")
            $t = [regex]::Replace($t, '(?i)</li\s*>', '')
            $t = [regex]::Replace($t, '(?i)</?(a|abbr|b|big|blockquote|caption|center|cite|dd|del|details|dfn|dl|dt|em|font|hr|i|img|ins|kbd|mark|pre|s|samp|small|span|strike|strong|sub|summary|sup|tbody|td|tfoot|th|thead|tt|u|var)\b(\s[^<>]*)?/?>', '')
            $t = $t.Replace('&lt;', '<').Replace('&gt;', '>').Replace('&quot;', '"').Replace('&#39;', "'").Replace('&apos;', "'").Replace('&nbsp;', ' ').Replace('&amp;', '&')
            $t = [regex]::Replace($t, '!\[([^\]]*)\]\(\s*([^)\s]+)[^)]*\)', {
                    param($Match)
                    if ($Match.Groups[1].Value.Trim() -eq '') { $Match.Groups[2].Value } else { "$($Match.Groups[1].Value) ($($Match.Groups[2].Value))" }
                })
            $t = [regex]::Replace($t, '\[([^\]]+)\]\(\s*([^)\s]+)[^)]*\)', {
                    param($Match)
                    if ($Match.Groups[1].Value -eq $Match.Groups[2].Value) { $Match.Groups[2].Value } else { "$($Match.Groups[1].Value) ($($Match.Groups[2].Value))" }
                })
            $t = [regex]::Replace($t, '(?m)^(\s*)[*+]\s+', '$1- ')
            $t = [regex]::Replace($t, '\*\*(.+?)\*\*', '$1')
            $t = [regex]::Replace($t, '(?<![\w_])__(.+?)__(?![\w_])', '$1')
            $t = [regex]::Replace($t, '(?<![\w*])\*(?![\s*])(.+?)(?<![\s*])\*(?![\w*])', '$1')
            $t = [regex]::Replace($t, '~~(.+?)~~', '$1')
            $t = [regex]::Replace($t, '(?m)^\s{0,3}#{1,6}[ \t]+(.*?)[ \t#]*$', "`n`$1`n")
            $t = [regex]::Replace($t, '(?m)^\s{0,3}>[ \t]?', '')
            $t = [regex]::Replace($t, '(?<=\S) {2,}(?=\S)', ' ')
            $t = [regex]::Replace($t, '[\uE000-\uE07F]', {
                    param($Match)
                    [string][char]([int][char]$Match.Value[0] - 0xE000)
                })
            # MDX: '<' starts JSX and '{' an expression, so words that hold them become code
            $t = [regex]::Replace($t, '[^\s]*[<{}][^\s]*', {
                    param($Match)
                    $word = $Match.Value
                    $lead = [regex]::Match($word, '^[(\["'']*').Value
                    $rest = $word.Substring($lead.Length)
                    $trail = [regex]::Match($rest, '[)\]"'',.;:!?]*$').Value
                    $core = $rest.Substring(0, $rest.Length - $trail.Length)
                    if ($core -eq '') {
                        $core = $rest
                        $trail = ''
                    }
                    $lead + '`' + $core.Replace('`', '') + '`' + $trail
                })
            $t
        }
        -join $converted
    }

    $result = (-join $parts).Split("`n") | ForEach-Object -Process {
        $line = $_.TrimEnd()
        if ($line -cmatch '^(\s*)(import|export)(\s)') {
            $line = $Matches[1] + $Matches[2].Substring(0, 1).ToUpperInvariant() + $Matches[2].Substring(1) + $line.Substring($Matches[0].Length - 1)
        }
        $line
    }
    $result = [regex]::Replace(($result -join "`n"), '\n{3,}', "`n`n").Trim("`n", ' ')
    if ($SingleLine) {
        $result = [regex]::Replace($result, '\s*\n\s*', ' ')
    }
    return $result
}
