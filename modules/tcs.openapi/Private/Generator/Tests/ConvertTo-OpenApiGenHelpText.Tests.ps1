BeforeAll {
    $env:TCS_CONFIG_ROOT = Join-Path -Path $TestDrive -ChildPath 'config'
    $env:TCS_SKIP_UPDATE_CHECK = '1'
    $env:TCS_TELEMETRY_OPTOUT = '1'
    $ModuleRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent
    Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'tcs.openapi.psd1') -Force
}

Describe 'ConvertTo-OpenApiGenHelpText' {
    BeforeAll {
        function ConvertTo-TestHelpText {
            param([string]$Text, [switch]$SingleLine)
            InModuleScope tcs.openapi -Parameters @{ Text = $Text; SingleLine = $SingleLine } {
                param($Text, $SingleLine)
                ConvertTo-OpenApiGenHelpText -Text $Text -SingleLine:$SingleLine
            }
        }
        # What MDX would read as JSX or an expression: '<' or '{' or '}' outside code spans and fences
        function Get-TestMdxHazard {
            param([string]$Text)
            $prose = [regex]::Replace($Text, '(?ms)^```.*?^```', '')
            $prose = [regex]::Replace($prose, '`[^`\n]*`', '')
            @([regex]::Matches($prose, '[<{}]') | ForEach-Object -Process { $_.Value })
        }
    }

    It 'returns an empty string for <Name>' -TestCases @(@{ Name = 'null'; Value = $null }, @{ Name = 'whitespace'; Value = " `n " }) {
        param($Value)
        ConvertTo-TestHelpText -Text $Value | Should -BeExactly ''
    }

    It 'turns <Name> into plain text' -TestCases @(
        @{ Name = 'br tags'; Text = 'One.<br/><br/>Two.<BR>Three.'; Expected = "One.`n`nTwo.`nThree." }
        @{ Name = 'bold and emphasis'; Text = '**Note**: __very__ *important* ~~old~~'; Expected = 'Note: very important old' }
        @{ Name = 'Markdown links'; Text = 'See [the docs](https://x.io/a "t") or [https://y.io](https://y.io).'; Expected = 'See the docs (https://x.io/a) or https://y.io.' }
        @{ Name = 'autolinks and anchors'; Text = '<https://x.io> and <a href="https://y.io">here</a>'; Expected = 'https://x.io and here (https://y.io)' }
        @{ Name = 'paragraph and list tags'; Text = '<p>A</p><ul><li>B</li><li>C</li></ul>'; Expected = "A`n`n- B`n- C" }
        @{ Name = 'Markdown lists and headings'; Text = "## Title`n* one`n+ two"; Expected = "Title`n`n- one`n- two" }
        @{ Name = 'entities'; Text = 'a &amp; b &quot;c&quot; &#39;d&#39;&nbsp;e'; Expected = 'a & b "c" ''d'' e' }
        @{ Name = 'backslash escapes'; Text = 'a \*star\* b'; Expected = 'a *star* b' }
        @{ Name = 'HTML comments'; Text = 'a <!-- hidden --> b'; Expected = 'a b' }
        @{ Name = 'code tags'; Text = 'use <code>x</code> here'; Expected = 'use `x` here' }
    ) {
        param($Text, $Expected)
        ConvertTo-TestHelpText -Text $Text | Should -BeExactly $Expected
    }

    It 'puts words with <Name> in backticks' -TestCases @(
        @{ Name = 'a path template'; Text = 'Calls (/v1/{id}/x).'; Expected = 'Calls (`/v1/{id}/x`).' }
        @{ Name = 'a generic type'; Text = 'Returns List<string> items.'; Expected = 'Returns `List<string>` items.' }
        @{ Name = 'an escaped brace'; Text = 'Use \{id\} here'; Expected = 'Use `{id}` here' }
        @{ Name = 'a decoded tag'; Text = 'The &lt;b&gt; tag'; Expected = 'The `<b>` tag' }
        @{ Name = 'a lone less-than'; Text = 'a < b'; Expected = 'a `<` b' }
    ) {
        param($Text, $Expected)
        ConvertTo-TestHelpText -Text $Text | Should -BeExactly $Expected
    }

    It 'keeps code spans and fenced code as they are' {
        $text = ConvertTo-TestHelpText -Text "Use ``Get<T> **x**`` now.`n``````json`n{ ""a"": ""<b>"" }`n```````nDone."
        $text | Should -BeExactly "Use ``Get<T> **x**`` now.`n``````json`n{ ""a"": ""<b>"" }`n```````nDone."
    }

    It 'closes an unclosed fence' {
        ConvertTo-TestHelpText -Text "Text`n``````json`n{ ""a"": 1 }" | Should -BeExactly "Text`n``````json`n{ ""a"": 1 }`n``````"
    }

    It 'capitalises a line that MDX would read as ESM' {
        ConvertTo-TestHelpText -Text "export the data`nimport it again" | Should -BeExactly "Export the data`nImport it again"
    }

    It 'joins the lines with -SingleLine' {
        ConvertTo-TestHelpText -Text "Line one.<br/>`n`nLine two." -SingleLine | Should -BeExactly 'Line one. Line two.'
    }

    It 'leaves nothing MDX would read as JSX or an expression in the UniFi descriptions' {
        $RepoRoot = Split-Path -Path (Split-Path -Path (Split-Path -Path (Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent) -Parent) -Parent) -Parent
        $document = Get-Content -LiteralPath (Join-Path -Path $RepoRoot -ChildPath 'tests/Fixtures/unifi-site-manager-1.0.0.json') -Raw | ConvertFrom-Json
        $texts = foreach ($path in $document.paths.PSObject.Properties) {
            foreach ($operation in $path.Value.PSObject.Properties) {
                $operation.Value.summary
                $operation.Value.description
                foreach ($parameter in @($operation.Value.parameters)) {
                    $parameter.description
                }
            }
        }
        foreach ($text in @($texts | Where-Object -FilterScript { -not [string]::IsNullOrWhiteSpace($_) })) {
            $converted = ConvertTo-TestHelpText -Text $text
            Get-TestMdxHazard -Text $converted | Should -BeNullOrEmpty -Because $converted
            $converted | Should -Not -Match '<br|\*\*'
        }
    }
}
