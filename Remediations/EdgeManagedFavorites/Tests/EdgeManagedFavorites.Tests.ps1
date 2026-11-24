<#
    Script:      EdgeManagedFavorites.Tests.ps1
    Author:      Daniel Fraubaum
    Version:     1.1
    Date:        2026-11-24
    Description: Pester 5 unit tests for EdgeManagedFavorites_Detect.ps1 and EdgeManagedFavorites_Remediate.ps1.
                 Only the function definitions are loaded from the scripts (via AST), the Logic part is
                 never executed and the registry is not touched. Every merge test runs twice: once as is
                 and once with the System.Array "Count" type data of Windows PowerShell 5.1, which makes
                 ConvertTo-Json write {"value":[...],"Count":n} for arrays that went through the pipeline.
    Run:         Invoke-Pester -Path .\Tests -Output Detailed
#>

BeforeDiscovery {
    $ScriptRoot = Split-Path -Path $PSScriptRoot -Parent
    $ScriptFiles = @(
        @{ ScriptName = "Detect";    ScriptPath = Join-Path -Path $ScriptRoot -ChildPath "EdgeManagedFavorites_Detect.ps1" }
        @{ ScriptName = "Remediate"; ScriptPath = Join-Path -Path $ScriptRoot -ChildPath "EdgeManagedFavorites_Remediate.ps1" }
    )
    $Modes = @(
        @{ Mode = "default" }
        @{ Mode = "PS 5.1 array type data" }
    )
}

BeforeAll {
    $ScriptRoot = Split-Path -Path $PSScriptRoot -Parent
    $DetectPath = Join-Path -Path $ScriptRoot -ChildPath "EdgeManagedFavorites_Detect.ps1"
    $RemediatePath = Join-Path -Path $ScriptRoot -ChildPath "EdgeManagedFavorites_Remediate.ps1"

    function Get-ScriptAst {
        param([string]$Path)
        $Tokens = $null
        $Errors = $null
        $Ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$Errors)
        return [pscustomobject]@{ Ast = $Ast; Errors = @($Errors) }
    }

    # Returns the source text of all top level function definitions of a script
    function Get-ScriptFunctionText {
        param([string]$Path)
        $Parsed = Get-ScriptAst -Path $Path
        if ($Parsed.Errors.Count -gt 0) { throw "Parse errors in $Path" }
        $Functions = $Parsed.Ast.FindAll({ param($Node) $Node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)
        return (@($Functions | ForEach-Object { $_.Extent.Text }) -join "`n`n")
    }

    # Returns the text between the "# ===" line above $StartMarker and the "# ===" line above $EndMarker
    function Get-ScriptSection {
        param([string]$Path, [string]$StartMarker, [string]$EndMarker)
        $Text = [System.IO.File]::ReadAllText($Path)
        $Start = $Text.LastIndexOf("# ===", $Text.IndexOf($StartMarker))
        $End = $Text.LastIndexOf("# ===", $Text.IndexOf($EndMarker))
        return $Text.Substring($Start, $End - $Start)
    }

    # Builds a set object the same way Get-StoredSets returns it from the registry
    function New-TestSet {
        param(
            [string]$Name,
            [array]$Favorites = @(),
            [string]$TopLevelName = "",
            [string]$LastUpdated = (Get-Date).ToUniversalTime().ToString("o")
        )
        $SetName = $Name
        return [pscustomobject]@{
            Name          = $Name
            FavoritesJson = (ConvertTo-SetJson -Items $Favorites)
            TopLevelName  = $TopLevelName
            LastUpdated   = $LastUpdated
        }
    }

    # Merges sets like the scripts do (sorting by SetName via Get-EffectiveSets)
    function Merge-TestSet {
        param([array]$Sets, [int]$StaleDays = 30)
        $Effective = Get-EffectiveSets -StoredSets $Sets -OwnName "__none__" -OwnJson "" -OwnTopLevelName "" -RemoveOwn $true -StaleDays $StaleDays
        return (Build-ManagedFavoritesJson -Sets $Effective)
    }

    # ConvertFrom-Json that keeps a top level array with one element as array in PowerShell 5.1 and 7
    function ConvertFrom-PolicyJson {
        param([string]$Json)
        if ($PSVersionTable.PSVersion.Major -ge 7) { return ,(ConvertFrom-Json -InputObject $Json -NoEnumerate) }
        return ,(ConvertFrom-Json -InputObject $Json)
    }

    # Asserts the Edge ManagedFavorites format: optional {toplevel_name} first, then {name,url} or {name,children}
    function Assert-EdgeFormat {
        param($Entries, [bool]$IsRoot = $true)
        ($Entries -is [array]) | Should -BeTrue -Because "every level of ManagedFavorites must be a JSON array"
        for ($Index = 0; $Index -lt $Entries.Count; $Index++) {
            $Entry = $Entries[$Index]
            $Properties = (@($Entry.PSObject.Properties.Name) | Sort-Object) -join ","
            if ($IsRoot -and $Index -eq 0 -and $Properties -eq "toplevel_name") {
                $Entry.toplevel_name | Should -BeOfType [string]
                continue
            }
            $Properties | Should -BeIn @("name,url", "children,name") -Because "entry $Index must be a link or a folder"
            $Entry.name | Should -BeOfType [string]
            $Entry.name | Should -Not -BeNullOrEmpty
            if ($Properties -eq "name,url") {
                $Entry.url | Should -BeOfType [string]
                $Entry.url | Should -Not -BeNullOrEmpty
            }
            else {
                $Entry.children.Count | Should -BeGreaterThan 0
                Assert-EdgeFormat -Entries $Entry.children -IsRoot $false
            }
        }
    }

    # Compact text form of a parsed tree: F:<folder>[...] and L:<name>=<url>, separated by |
    function Get-TreeText {
        param($Entries)
        $Parts = foreach ($Entry in $Entries) {
            $Names = @($Entry.PSObject.Properties.Name)
            if ($Names -contains "toplevel_name") { "T:$($Entry.toplevel_name)" }
            elseif ($Names -contains "children") { "F:$($Entry.name)[$(Get-TreeText -Entries $Entry.children)]" }
            else { "L:$($Entry.name)=$($Entry.url)" }
        }
        return (@($Parts) -join "|")
    }

    function Get-PolicyTree {
        param([string]$Json)
        $Parsed = ConvertFrom-PolicyJson -Json $Json
        Assert-EdgeFormat -Entries $Parsed
        return (Get-TreeText -Entries $Parsed)
    }
}

Describe "Script files" {
    It "<Name> parses without errors" -ForEach @(
        @{ Name = "Detect"; File = "EdgeManagedFavorites_Detect.ps1" }
        @{ Name = "Remediate"; File = "EdgeManagedFavorites_Remediate.ps1" }
    ) {
        $Parsed = Get-ScriptAst -Path (Join-Path -Path $ScriptRoot -ChildPath $File)
        $Parsed.Errors.Count | Should -Be 0
    }

    It "<Name> is UTF-8 with BOM and CRLF only" -ForEach @(
        @{ Name = "Detect"; File = "EdgeManagedFavorites_Detect.ps1" }
        @{ Name = "Remediate"; File = "EdgeManagedFavorites_Remediate.ps1" }
    ) {
        $Bytes = [System.IO.File]::ReadAllBytes((Join-Path -Path $ScriptRoot -ChildPath $File))
        $Bytes[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
        $Text = [System.Text.Encoding]::UTF8.GetString($Bytes)
        ([regex]::Matches($Text, "(?<!`r)`n")).Count | Should -Be 0
        $Text | Should -Not -Match ([string][char]0x2014)
    }

    It "Parameters and Functions sections are byte-identical in Detect and Remediate" {
        $Detect = Get-ScriptSection -Path $DetectPath -StartMarker "# Parameters" -EndMarker "# Logic"
        $Remediate = Get-ScriptSection -Path $RemediatePath -StartMarker "# Parameters" -EndMarker "# Logic"
        $Detect.Length | Should -BeGreaterThan 1000
        ($Detect -ceq $Remediate) | Should -BeTrue
    }

    It "Version and Date in the header are the same in both scripts" {
        $Detect = [System.IO.File]::ReadAllText($DetectPath)
        $Remediate = [System.IO.File]::ReadAllText($RemediatePath)
        foreach ($Field in "Version", "Date") {
            $Pattern = "(?m)^\s+$($Field):\s+(\S+)"
            ([regex]::Match($Detect, $Pattern).Groups[1].Value) | Should -Be ([regex]::Match($Remediate, $Pattern).Groups[1].Value)
        }
    }

    It "Detect compares favorites, top level name and policy JSON case-sensitive" {
        $Logic = (Get-ScriptAst -Path $DetectPath).Ast.FindAll({ param($Node) $Node -is [System.Management.Automation.Language.BinaryExpressionAst] }, $true)
        $Comparisons = @($Logic | Where-Object { $_.Extent.Text -match "Json|TopLevelName" -and $_.Operator -match "eq|ne" })
        $Comparisons.Count | Should -BeGreaterOrEqual 3
        foreach ($Comparison in $Comparisons) {
            $Comparison.Operator.ToString() | Should -BeIn @("Ceq", "Cne") -Because "'$($Comparison.Extent.Text)' must detect case-only changes"
        }
    }
}

Describe "Merge logic of <ScriptName> script" -ForEach $ScriptFiles {
    Context "<Mode>" -ForEach $Modes {
        BeforeAll {
            . ([scriptblock]::Create((Get-ScriptFunctionText -Path $ScriptPath)))
            $SetName = "UnitTest"
            $AddedTypeData = $false
            if ($Mode -ne "default" -and $PSVersionTable.PSVersion.Major -ge 6) {
                # Windows PowerShell 5.1 ships this alias, pwsh 7 does not. Windows PowerShell 5.1 already has it.
                Update-TypeData -TypeName System.Array -MemberType AliasProperty -MemberName Count -Value Length -Force
                $AddedTypeData = $true
            }
        }

        AfterAll {
            if ($AddedTypeData) { Remove-TypeData -TypeName System.Array }
        }

        It "runs with the expected ConvertTo-Json array behavior" {
            function Get-WrappedArray { , @(1) }
            $Expected = if ($Mode -eq "default" -and $PSVersionTable.PSVersion.Major -ge 6) { "[1]" } else { '{"value":[1],"Count":1}' }
            (Get-WrappedArray | ConvertTo-Json -Compress) | Should -BeExactly $Expected -Because "the PS 5.1 trap must be active in the PS 5.1 mode"
        }

        Context "Assert-Configuration" {
            It "accepts SetName '<Name>' with StaleDays <Stale> and RefreshDays <Refresh>" -ForEach @(
                @{ Name = "General"; Stale = 30; Refresh = 7 }
                @{ Name = "IT Admins 2"; Stale = 30; Refresh = 29 }
                @{ Name = "Team-A.B_C"; Stale = 0; Refresh = 0 }
                @{ Name = "Never stale"; Stale = 0; Refresh = 7 }
            ) {
                { Assert-Configuration -Name $Name -StaleDays $Stale -RefreshDays $Refresh } | Should -Not -Throw
            }

            It "rejects SetName '<Name>'" -ForEach @(
                @{ Name = "" }
                @{ Name = "   " }
                @{ Name = "IT\Admins" }
                @{ Name = "IT/Admins" }
                @{ Name = "Team [IT]" }
                @{ Name = "Team*" }
                @{ Name = "Team?" }
            ) {
                { Assert-Configuration -Name $Name -StaleDays 30 -RefreshDays 7 } | Should -Throw "*Invalid SetName*"
            }

            It "rejects RefreshDays <Refresh> with StaleDays <Stale>" -ForEach @(
                @{ Stale = 30; Refresh = 0 }
                @{ Stale = 30; Refresh = 30 }
                @{ Stale = 30; Refresh = 45 }
                @{ Stale = 1; Refresh = 1 }
            ) {
                { Assert-Configuration -Name "General" -StaleDays $Stale -RefreshDays $Refresh } | Should -Throw "*RefreshAfterDays*"
            }
        }

        Context "Get-NormalizedPath" {
            It "normalizes '<InputPath>' to '<Expected>'" -ForEach @(
                @{ InputPath = "/a//b/ "; Expected = "a/b" }
                @{ InputPath = " a / b "; Expected = "a/b" }
                @{ InputPath = "a/b/c"; Expected = "a/b/c" }
                @{ InputPath = "///"; Expected = "" }
                @{ InputPath = "   "; Expected = "" }
                @{ InputPath = ""; Expected = "" }
                @{ InputPath = $null; Expected = "" }
            ) {
                Get-NormalizedPath -Path $InputPath | Should -BeExactly $Expected
            }
        }

        Context "ConvertTo-SetJson" {
            It "keeps a set with exactly one favorite as JSON array" {
                $Json = ConvertTo-SetJson -Items @(@{ Path = ""; Name = "One"; Url = "https://one.example" })
                $Json | Should -BeExactly '[{"Path":"","Name":"One","Url":"https://one.example"}]'
            }

            It "stores normalized and trimmed values" {
                $Json = ConvertTo-SetJson -Items @(@{ Path = "/a//b/ "; Name = " Name "; Url = " https://x.example " })
                $Json | Should -BeExactly '[{"Path":"a/b","Name":"Name","Url":"https://x.example"}]'
            }

            It "treats a missing Path as root" {
                $Json = ConvertTo-SetJson -Items @(@{ Name = "Root"; Url = "https://root.example" })
                $Json | Should -BeExactly '[{"Path":"","Name":"Root","Url":"https://root.example"}]'
            }

            It "returns an empty JSON array for an empty set" {
                ConvertTo-SetJson -Items @() | Should -BeExactly "[]"
            }

            It "is independent of the order of the favorites" {
                $A = @{ Path = "x"; Name = "A"; Url = "https://a.example" }
                $B = @{ Path = ""; Name = "B"; Url = "https://b.example" }
                ConvertTo-SetJson -Items @($A, $B) | Should -BeExactly (ConvertTo-SetJson -Items @($B, $A))
            }

            It "detects a URL change in upper/lower case only" {
                $Old = ConvertTo-SetJson -Items @(@{ Path = ""; Name = "Intune"; Url = "https://intune.microsoft.com/page" })
                $New = ConvertTo-SetJson -Items @(@{ Path = ""; Name = "Intune"; Url = "https://intune.microsoft.com/Page" })
                ($Old -ne $New) | Should -BeFalse -Because "-ne ignores case, that is why Detect has to use -cne"
                ($Old -cne $New) | Should -BeTrue
            }

            It "throws for <Case>" -ForEach @(
                @{ Case = "empty Name"; Item = @{ Path = ""; Name = ""; Url = "https://x.example" } }
                @{ Case = "whitespace Name"; Item = @{ Path = ""; Name = "  "; Url = "https://x.example" } }
                @{ Case = "missing Name"; Item = @{ Path = ""; Url = "https://x.example" } }
                @{ Case = "empty Url"; Item = @{ Path = ""; Name = "X"; Url = "" } }
                @{ Case = "missing Url"; Item = @{ Path = ""; Name = "X" } }
            ) {
                { ConvertTo-SetJson -Items @($Item) } | Should -Throw "*empty Name or Url*"
            }
        }

        Context "Test-IsStale" {
            It "returns <Expected> for <Case>" -ForEach @(
                @{ Case = "fresh timestamp"; Offset = -1; Days = 30; Expected = $false }
                @{ Case = "timestamp older than the limit"; Offset = -31; Days = 30; Expected = $true }
                @{ Case = "future timestamp"; Offset = 2; Days = 30; Expected = $false }
                @{ Case = "Days 0 and very old timestamp"; Offset = -3650; Days = 0; Expected = $false }
            ) {
                $Stamp = (Get-Date).ToUniversalTime().AddDays($Offset).ToString("o")
                Test-IsStale -LastUpdated $Stamp -Days $Days | Should -Be $Expected
            }

            It "treats '<Value>' as stale" -ForEach @(
                @{ Value = "not a date" }
                @{ Value = "" }
                @{ Value = $null }
            ) {
                Test-IsStale -LastUpdated $Value -Days 30 | Should -BeTrue
            }

            It "never treats an invalid value as stale with Days 0" {
                Test-IsStale -LastUpdated "not a date" -Days 0 | Should -BeFalse
            }
        }

        Context "Get-EffectiveSets" {
            BeforeAll {
                $Fresh = (Get-Date).ToUniversalTime().ToString("o")
                $Old = (Get-Date).ToUniversalTime().AddDays(-40).ToString("o")
                $Stored = @(
                    [pscustomobject]@{ Name = "Zeta"; FavoritesJson = "[]"; TopLevelName = ""; LastUpdated = $Fresh }
                    [pscustomobject]@{ Name = "Own"; FavoritesJson = "OLD"; TopLevelName = "Old"; LastUpdated = $Fresh }
                    [pscustomobject]@{ Name = "Stale"; FavoritesJson = "[]"; TopLevelName = ""; LastUpdated = $Old }
                    [pscustomobject]@{ Name = "Broken"; FavoritesJson = "[]"; TopLevelName = ""; LastUpdated = "garbage" }
                    [pscustomobject]@{ Name = "alpha"; FavoritesJson = "[]"; TopLevelName = ""; LastUpdated = $Fresh }
                )
            }

            It "replaces the stored own set with the desired state and sorts by name" {
                $Result = Get-EffectiveSets -StoredSets $Stored -OwnName "Own" -OwnJson "NEW" -OwnTopLevelName "New" -RemoveOwn $false -StaleDays 30
                @($Result | ForEach-Object { $_.Name }) | Should -Be @("alpha", "Own", "Zeta")
                ($Result | Where-Object { $_.Name -eq "Own" }).FavoritesJson | Should -BeExactly "NEW"
                ($Result | Where-Object { $_.Name -eq "Own" }).TopLevelName | Should -BeExactly "New"
            }

            It "removes the own set with RemoveOwn" {
                $Result = Get-EffectiveSets -StoredSets $Stored -OwnName "Own" -OwnJson "NEW" -OwnTopLevelName "" -RemoveOwn $true -StaleDays 30
                @($Result | ForEach-Object { $_.Name }) | Should -Be @("alpha", "Zeta")
            }

            It "matches the own set name case-insensitive like the registry" {
                $Result = Get-EffectiveSets -StoredSets $Stored -OwnName "OWN" -OwnJson "NEW" -OwnTopLevelName "" -RemoveOwn $true -StaleDays 30
                @($Result | ForEach-Object { $_.Name }) | Should -Not -Contain "Own"
            }

            It "keeps stale and invalid sets with StaleDays 0" {
                $Result = Get-EffectiveSets -StoredSets $Stored -OwnName "Own" -OwnJson "NEW" -OwnTopLevelName "" -RemoveOwn $true -StaleDays 0
                @($Result | ForEach-Object { $_.Name }) | Should -Be @("alpha", "Broken", "Stale", "Zeta")
            }

            It "returns an empty array when nothing is left" {
                $Result = Get-EffectiveSets -StoredSets @() -OwnName "Own" -OwnJson "" -OwnTopLevelName "" -RemoveOwn $true -StaleDays 30
                @($Result).Count | Should -Be 0
            }

            It "returns an array with one set when only the own set exists" {
                $Result = Get-EffectiveSets -StoredSets @() -OwnName "Own" -OwnJson "[]" -OwnTopLevelName "" -RemoveOwn $false -StaleDays 30
                , $Result | Should -BeOfType [array]
                $Result.Count | Should -Be 1
            }
        }

        Context "Build-ManagedFavoritesJson" {
            It "builds one set with root links only" {
                $Set = New-TestSet -Name "A" -Favorites @(
                    @{ Path = ""; Name = "Zulu"; Url = "https://z.example" }
                    @{ Path = ""; Name = "alpha"; Url = "https://a.example" }
                )
                $Json = Merge-TestSet -Sets @($Set)
                Get-PolicyTree -Json $Json | Should -BeExactly "L:alpha=https://a.example|L:Zulu=https://z.example"
            }

            It "keeps a policy with exactly one link as JSON array" {
                $Json = Merge-TestSet -Sets @(New-TestSet -Name "A" -Favorites @(@{ Path = ""; Name = "One"; Url = "https://one.example" }))
                $Json | Should -BeExactly '[{"name":"One","url":"https://one.example"}]'
            }

            It "keeps folders with exactly one child as JSON array on every level" {
                $Json = Merge-TestSet -Sets @(New-TestSet -Name "A" -Favorites @(@{ Path = "L1/L2/L3"; Name = "Deep"; Url = "https://deep.example" }))
                $Json | Should -BeExactly '[{"name":"L1","children":[{"name":"L2","children":[{"name":"L3","children":[{"name":"Deep","url":"https://deep.example"}]}]}]}]'
                $Json | Should -Not -Match '"value"|"Count"'
            }

            It "builds nested paths with 3 levels" {
                $Set = New-TestSet -Name "A" -Favorites @(
                    @{ Path = "L1"; Name = "One"; Url = "https://1.example" }
                    @{ Path = "L1/L2"; Name = "Two"; Url = "https://2.example" }
                    @{ Path = "L1/L2/L3"; Name = "Three"; Url = "https://3.example" }
                    @{ Path = "L1/L2/L3"; Name = "Three b"; Url = "https://3b.example" }
                )
                $Json = Merge-TestSet -Sets @($Set)
                Get-PolicyTree -Json $Json | Should -BeExactly "F:L1[F:L2[F:L3[L:Three=https://3.example|L:Three b=https://3b.example]|L:Two=https://2.example]|L:One=https://1.example]"
            }

            It "normalizes paths before merging" {
                $A = New-TestSet -Name "A" -Favorites @(@{ Path = "/a//b/ "; Name = "X"; Url = "https://x.example" })
                $B = New-TestSet -Name "B" -Favorites @(@{ Path = "a/b"; Name = "Y"; Url = "https://y.example" })
                Get-PolicyTree -Json (Merge-TestSet -Sets @($A, $B)) | Should -BeExactly "F:a[F:b[L:X=https://x.example|L:Y=https://y.example]]"
            }

            It "merges the same folder in different upper/lower case from several sets" {
                $A = New-TestSet -Name "A" -Favorites @(@{ Path = "Admin Portals/Security"; Name = "Defender"; Url = "https://security.microsoft.com" })
                $B = New-TestSet -Name "B" -Favorites @(@{ Path = "admin portals"; Name = "Intune"; Url = "https://intune.microsoft.com" })
                $C = New-TestSet -Name "C" -Favorites @(@{ Path = "ADMIN PORTALS/security"; Name = "Purview"; Url = "https://purview.microsoft.com" })
                $Tree = Get-PolicyTree -Json (Merge-TestSet -Sets @($C, $B, $A))
                $Tree | Should -BeExactly "F:Admin Portals[F:Security[L:Defender=https://security.microsoft.com|L:Purview=https://purview.microsoft.com]|L:Intune=https://intune.microsoft.com]"
            }

            It "deduplicates the same link from several sets" {
                $Link = @{ Path = "Portals"; Name = "Intune"; Url = "https://intune.microsoft.com" }
                $A = New-TestSet -Name "A" -Favorites @($Link, @{ Path = ""; Name = "Only A"; Url = "https://a.example" })
                $B = New-TestSet -Name "B" -Favorites @($Link)
                $C = New-TestSet -Name "C" -Favorites @(@{ Path = "portals"; Name = "INTUNE"; Url = "https://INTUNE.microsoft.com" })
                $Tree = Get-PolicyTree -Json (Merge-TestSet -Sets @($A, $B, $C))
                $Tree | Should -BeExactly "F:Portals[L:Intune=https://intune.microsoft.com]|L:Only A=https://a.example"
            }

            It "keeps links with the same name but different URLs" {
                $A = New-TestSet -Name "A" -Favorites @(@{ Path = ""; Name = "Portal"; Url = "https://b.example" })
                $B = New-TestSet -Name "B" -Favorites @(@{ Path = ""; Name = "Portal"; Url = "https://a.example" })
                Get-PolicyTree -Json (Merge-TestSet -Sets @($A, $B)) | Should -BeExactly "L:Portal=https://a.example|L:Portal=https://b.example"
            }

            It "sorts folders before links and both alphabetically on every level" {
                $Set = New-TestSet -Name "A" -Favorites @(
                    @{ Path = ""; Name = "aaa link"; Url = "https://1.example" }
                    @{ Path = "zeta"; Name = "z2"; Url = "https://2.example" }
                    @{ Path = "Alpha"; Name = "b"; Url = "https://3.example" }
                    @{ Path = "Alpha"; Name = "A"; Url = "https://4.example" }
                    @{ Path = "Alpha/Sub"; Name = "s"; Url = "https://5.example" }
                    @{ Path = ""; Name = "Beta link"; Url = "https://6.example" }
                    @{ Path = "beta"; Name = "x"; Url = "https://7.example" }
                )
                $Tree = Get-PolicyTree -Json (Merge-TestSet -Sets @($Set))
                $Tree | Should -BeExactly "F:Alpha[F:Sub[L:s=https://5.example]|L:A=https://4.example|L:b=https://3.example]|F:beta[L:x=https://7.example]|F:zeta[L:z2=https://2.example]|L:aaa link=https://1.example|L:Beta link=https://6.example"
            }

            It "uses the top level name of the first set by SetName that has one" {
                $Link = @{ Path = ""; Name = "X"; Url = "https://x.example" }
                $Sets = @(
                    New-TestSet -Name "Charlie" -Favorites @($Link) -TopLevelName "From Charlie"
                    New-TestSet -Name "alpha" -Favorites @($Link) -TopLevelName "   "
                    New-TestSet -Name "Bravo" -Favorites @() -TopLevelName "  From Bravo  "
                )
                $Json = Merge-TestSet -Sets $Sets
                $Parsed = ConvertFrom-PolicyJson -Json $Json
                Get-PolicyTree -Json $Json | Should -BeExactly "T:From Bravo|L:X=https://x.example"
                @($Parsed[0].PSObject.Properties.Name) | Should -Be @("toplevel_name")
            }

            It "writes no toplevel_name entry when no set has one" {
                $Json = Merge-TestSet -Sets @(New-TestSet -Name "A" -Favorites @(@{ Path = ""; Name = "X"; Url = "https://x.example" }))
                $Json | Should -Not -Match "toplevel_name"
            }

            It "returns an empty string when <Case>" -ForEach @(
                @{ Case = "there are no sets"; Sets = @() }
                @{ Case = "all sets are empty"; Sets = @(
                        [pscustomobject]@{ Name = "A"; FavoritesJson = "[]"; TopLevelName = "Name"; LastUpdated = (Get-Date).ToUniversalTime().ToString("o") }
                        [pscustomobject]@{ Name = "B"; FavoritesJson = ""; TopLevelName = ""; LastUpdated = (Get-Date).ToUniversalTime().ToString("o") }
                        [pscustomobject]@{ Name = "C"; FavoritesJson = $null; TopLevelName = $null; LastUpdated = (Get-Date).ToUniversalTime().ToString("o") }
                    )
                }
            ) {
                Merge-TestSet -Sets $Sets | Should -BeExactly ""
            }

            It "detects a URL change in upper/lower case only in the policy JSON" {
                $Old = Merge-TestSet -Sets @(New-TestSet -Name "A" -Favorites @(@{ Path = ""; Name = "X"; Url = "https://x.example/page" }))
                $New = Merge-TestSet -Sets @(New-TestSet -Name "A" -Favorites @(@{ Path = ""; Name = "X"; Url = "https://x.example/Page" }))
                ($Old -cne $New) | Should -BeTrue
            }

            It "ignores stale sets and drops the policy when only stale sets are left" {
                $Old = (Get-Date).ToUniversalTime().AddDays(-31).ToString("o")
                $Fresh = New-TestSet -Name "Fresh" -Favorites @(@{ Path = ""; Name = "Fresh"; Url = "https://fresh.example" })
                $Stale = New-TestSet -Name "Stale" -Favorites @(@{ Path = ""; Name = "Stale"; Url = "https://stale.example" }) -TopLevelName "Stale name" -LastUpdated $Old
                Get-PolicyTree -Json (Merge-TestSet -Sets @($Fresh, $Stale)) | Should -BeExactly "L:Fresh=https://fresh.example"
                Merge-TestSet -Sets @($Stale) | Should -BeExactly ""
                Get-PolicyTree -Json (Merge-TestSet -Sets @($Fresh, $Stale) -StaleDays 0) | Should -BeExactly "T:Stale name|L:Fresh=https://fresh.example|L:Stale=https://stale.example"
            }

            It "ignores a set with an invalid LastUpdated" {
                $Fresh = New-TestSet -Name "Fresh" -Favorites @(@{ Path = ""; Name = "Fresh"; Url = "https://fresh.example" })
                $Broken = New-TestSet -Name "Broken" -Favorites @(@{ Path = ""; Name = "Broken"; Url = "https://broken.example" }) -LastUpdated "garbage"
                Get-PolicyTree -Json (Merge-TestSet -Sets @($Fresh, $Broken)) | Should -BeExactly "L:Fresh=https://fresh.example"
            }

            It "removes the own set with RemoveSet and keeps the others" {
                $Stored = @(
                    New-TestSet -Name "General" -Favorites @(@{ Path = ""; Name = "General"; Url = "https://general.example" }) -TopLevelName "General name"
                    New-TestSet -Name "IT" -Favorites @(@{ Path = "IT"; Name = "Intune"; Url = "https://intune.microsoft.com" })
                )
                $OwnJson = ConvertTo-SetJson -Items @(@{ Path = ""; Name = "General"; Url = "https://general.example" })
                $Effective = Get-EffectiveSets -StoredSets $Stored -OwnName "General" -OwnJson $OwnJson -OwnTopLevelName "General name" -RemoveOwn $true -StaleDays 30
                Get-PolicyTree -Json (Build-ManagedFavoritesJson -Sets $Effective) | Should -BeExactly "F:IT[L:Intune=https://intune.microsoft.com]"
            }

            It "builds the default favorites of the script exactly" {
                $Favorites = @(
                    @{ Path = ""; Name = "Microsoft"; Url = "https://www.microsoft.com" }
                    @{ Path = "Admin Portals"; Name = "Intune"; Url = "https://intune.microsoft.com" }
                    @{ Path = "Admin Portals"; Name = "Entra"; Url = "https://entra.microsoft.com" }
                    @{ Path = "Admin Portals/Security"; Name = "Defender"; Url = "https://security.microsoft.com" }
                )
                $OwnJson = ConvertTo-SetJson -Items $Favorites
                $Effective = Get-EffectiveSets -StoredSets @() -OwnName "General" -OwnJson $OwnJson -OwnTopLevelName "Company Favorites" -RemoveOwn $false -StaleDays 30
                $Json = Build-ManagedFavoritesJson -Sets $Effective
                $Json | Should -BeExactly '[{"toplevel_name":"Company Favorites"},{"name":"Admin Portals","children":[{"name":"Security","children":[{"name":"Defender","url":"https://security.microsoft.com"}]},{"name":"Entra","url":"https://entra.microsoft.com"},{"name":"Intune","url":"https://intune.microsoft.com"}]},{"name":"Microsoft","url":"https://www.microsoft.com"}]'
                Get-PolicyTree -Json $Json | Should -Not -BeNullOrEmpty
            }
        }
    }
}
