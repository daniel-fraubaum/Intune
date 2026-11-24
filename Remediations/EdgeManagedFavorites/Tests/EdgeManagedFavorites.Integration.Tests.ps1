<#
    Script:      EdgeManagedFavorites.Integration.Tests.ps1
    Author:      Daniel Fraubaum
    Version:     1.1
    Date:        2026-11-24
    Description: Pester 5 integration tests against the real registry. Runs only on Windows in an elevated
                 session and is skipped everywhere else. The scripts are copied to TEMP with test values for
                 SetName, Favorites, RemoveSet, RegistryBasePath and EdgePolicyPath, so the real Edge policy
                 key is never touched. Everything below $TestRoot is removed afterwards.
                 The copies run in 64-bit Windows PowerShell 5.1 (powershell.exe), like Intune does.
    Run:         Invoke-Pester -Path .\Tests\EdgeManagedFavorites.Integration.Tests.ps1 -Output Detailed
#>

BeforeDiscovery {
    $IsWindowsHost = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    $IsElevated = $false
    if ($IsWindowsHost) {
        $Principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
        $IsElevated = $Principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    $SkipIntegration = -not ($IsWindowsHost -and $IsElevated)
}

BeforeAll {
    $ScriptRoot = Split-Path -Path $PSScriptRoot -Parent
    $DetectSource = Join-Path -Path $ScriptRoot -ChildPath "EdgeManagedFavorites_Detect.ps1"
    $RemediateSource = Join-Path -Path $ScriptRoot -ChildPath "EdgeManagedFavorites_Remediate.ps1"

    # Copies a script and replaces the right side of top level parameter assignments, e.g. @{ SetName = '"A"' }
    function New-ScriptCopy {
        param([string]$Source, [string]$Destination, [hashtable]$Overrides)
        $Tokens = $null
        $Errors = $null
        $Ast = [System.Management.Automation.Language.Parser]::ParseFile($Source, [ref]$Tokens, [ref]$Errors)
        if ($Errors.Count -gt 0) { throw "Parse errors in $Source" }
        $Text = $Ast.Extent.Text
        $Assignments = @($Ast.EndBlock.Statements | Where-Object {
                $_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $_.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $Overrides.ContainsKey($_.Left.VariablePath.UserPath)
            } | Sort-Object -Property { $_.Right.Extent.StartOffset } -Descending)
        if ($Assignments.Count -ne $Overrides.Count) { throw "Not all overrides found in $Source" }
        foreach ($Assignment in $Assignments) {
            $Value = $Overrides[$Assignment.Left.VariablePath.UserPath]
            $Start = $Assignment.Right.Extent.StartOffset
            $Text = $Text.Substring(0, $Start) + $Value + $Text.Substring($Assignment.Right.Extent.EndOffset)
        }
        [System.IO.File]::WriteAllText($Destination, $Text, (New-Object System.Text.UTF8Encoding($true)))
    }

    function Get-PowerShellExe {
        $Native = Join-Path -Path $env:SystemRoot -ChildPath "Sysnative\WindowsPowerShell\v1.0\powershell.exe"
        if (Test-Path -LiteralPath $Native) { return $Native }
        return (Join-Path -Path $env:SystemRoot -ChildPath "System32\WindowsPowerShell\v1.0\powershell.exe")
    }

    # Runs Detect or Remediate for one test set and returns exit code and output
    function Invoke-TestScript {
        param(
            [ValidateSet("Detect", "Remediate")][string]$Kind,
            [string]$SetName,
            [string]$Favorites,
            [string]$TopLevelName = "",
            [bool]$RemoveSet = $false
        )
        $Source = if ($Kind -eq "Detect") { $DetectSource } else { $RemediateSource }
        $Destination = Join-Path -Path $TestTemp -ChildPath ("{0}_{1}.ps1" -f $SetName, $Kind)
        New-ScriptCopy -Source $Source -Destination $Destination -Overrides @{
            SetName          = """$SetName"""
            TopLevelName     = """$TopLevelName"""
            Favorites        = $Favorites
            RemoveSet        = $(if ($RemoveSet) { '$true' } else { '$false' })
            RegistryBasePath = """$TestRoot"""
            EdgePolicyPath   = """$TestPolicyPath"""
        }
        $Output = & (Get-PowerShellExe) -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Destination 2>&1
        return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = (@($Output) -join "`n") }
    }

    function Get-PolicyValue {
        $Property = Get-ItemProperty -LiteralPath $TestPolicyPath -Name "ManagedFavorites" -ErrorAction SilentlyContinue
        if ($null -eq $Property) { return $null }
        return $Property.ManagedFavorites
    }

    $TestId = [guid]::NewGuid().ToString("N").Substring(0, 8)
    $TestRoot = "HKLM:\SOFTWARE\EdgeManagedFavoritesPesterTest_$TestId"
    $TestPolicyPath = "$TestRoot\EdgePolicy"
    $TestTemp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "EdgeManagedFavoritesPesterTest_$TestId"

    $FavoritesA = '@(
        @{ Path = ""; Name = "Microsoft"; Url = "https://www.microsoft.com" }
        @{ Path = "Admin Portals"; Name = "Intune"; Url = "https://intune.microsoft.com" }
    )'
    $FavoritesACaseChanged = '@(
        @{ Path = ""; Name = "Microsoft"; Url = "https://www.Microsoft.com" }
        @{ Path = "Admin Portals"; Name = "Intune"; Url = "https://intune.microsoft.com" }
    )'
    $FavoritesB = '@(
        @{ Path = "admin portals/Security"; Name = "Defender"; Url = "https://security.microsoft.com" }
        @{ Path = "admin portals"; Name = "Intune"; Url = "https://intune.microsoft.com" }
    )'
}

Describe "Integration against the real registry" -Skip:$SkipIntegration {
    BeforeAll {
        New-Item -Path $TestTemp -ItemType Directory -Force | Out-Null
        New-Item -Path $TestPolicyPath -Force | Out-Null
        New-ItemProperty -LiteralPath $TestPolicyPath -Name "OtherPolicy" -Value 1 -PropertyType DWord -Force | Out-Null
    }

    AfterAll {
        if (Test-Path -LiteralPath $TestRoot) { Remove-Item -LiteralPath $TestRoot -Recurse -Force }
        if (Test-Path -LiteralPath $TestTemp) { Remove-Item -LiteralPath $TestTemp -Recurse -Force }
    }

    It "Detect reports a missing set" {
        $Result = Invoke-TestScript -Kind Detect -SetName "A" -Favorites $FavoritesA -TopLevelName "Test Root"
        $Result.ExitCode | Should -Be 1
        $Result.Output | Should -Match "missing"
    }

    It "Remediate writes set A and the policy" {
        $Result = Invoke-TestScript -Kind Remediate -SetName "A" -Favorites $FavoritesA -TopLevelName "Test Root"
        $Result.ExitCode | Should -Be 0
        Test-Path -LiteralPath "$TestRoot\Sets\A" | Should -BeTrue
        Get-PolicyValue | Should -BeExactly '[{"toplevel_name":"Test Root"},{"name":"Admin Portals","children":[{"name":"Intune","url":"https://intune.microsoft.com"}]},{"name":"Microsoft","url":"https://www.microsoft.com"}]'
        (Get-ItemProperty -LiteralPath $TestPolicyPath).OtherPolicy | Should -Be 1
    }

    It "Detect reports set A as compliant" {
        $Result = Invoke-TestScript -Kind Detect -SetName "A" -Favorites $FavoritesA -TopLevelName "Test Root"
        $Result.ExitCode | Should -Be 0
    }

    It "Remediate of set B merges folders case-insensitive and deduplicates links" {
        $Result = Invoke-TestScript -Kind Remediate -SetName "B" -Favorites $FavoritesB
        $Result.ExitCode | Should -Be 0
        Get-PolicyValue | Should -BeExactly '[{"toplevel_name":"Test Root"},{"name":"Admin Portals","children":[{"name":"Security","children":[{"name":"Defender","url":"https://security.microsoft.com"}]},{"name":"Intune","url":"https://intune.microsoft.com"}]},{"name":"Microsoft","url":"https://www.microsoft.com"}]'
        (Invoke-TestScript -Kind Detect -SetName "A" -Favorites $FavoritesA -TopLevelName "Test Root").ExitCode | Should -Be 0
        (Invoke-TestScript -Kind Detect -SetName "B" -Favorites $FavoritesB).ExitCode | Should -Be 0
    }

    It "Detect finds a URL change in upper/lower case only and Remediate applies it" {
        $Result = Invoke-TestScript -Kind Detect -SetName "A" -Favorites $FavoritesACaseChanged -TopLevelName "Test Root"
        $Result.ExitCode | Should -Be 1
        (Invoke-TestScript -Kind Remediate -SetName "A" -Favorites $FavoritesACaseChanged -TopLevelName "Test Root").ExitCode | Should -Be 0
        Get-PolicyValue | Should -BeLikeExactly '*"url":"https://www.Microsoft.com"*'
        (Invoke-TestScript -Kind Detect -SetName "A" -Favorites $FavoritesACaseChanged -TopLevelName "Test Root").ExitCode | Should -Be 0
    }

    It "Detect reports a stale set B and Remediate of A removes it" {
        $Old = (Get-Date).ToUniversalTime().AddDays(-40).ToString("o")
        Set-ItemProperty -LiteralPath "$TestRoot\Sets\B" -Name "LastUpdated" -Value $Old
        $Result = Invoke-TestScript -Kind Detect -SetName "A" -Favorites $FavoritesACaseChanged -TopLevelName "Test Root"
        $Result.ExitCode | Should -Be 1
        $Result.Output | Should -Match "stale set"
        (Invoke-TestScript -Kind Remediate -SetName "A" -Favorites $FavoritesACaseChanged -TopLevelName "Test Root").ExitCode | Should -Be 0
        Test-Path -LiteralPath "$TestRoot\Sets\B" | Should -BeFalse
        Get-PolicyValue | Should -Not -Match "Defender"
    }

    It "RemoveSet removes set A and the policy value but keeps the policy key" {
        $Result = Invoke-TestScript -Kind Remediate -SetName "A" -Favorites $FavoritesA -RemoveSet $true
        $Result.ExitCode | Should -Be 0
        Test-Path -LiteralPath "$TestRoot\Sets\A" | Should -BeFalse
        Get-PolicyValue | Should -BeNullOrEmpty
        (Get-ItemProperty -LiteralPath $TestPolicyPath).OtherPolicy | Should -Be 1
        (Invoke-TestScript -Kind Detect -SetName "A" -Favorites $FavoritesA -RemoveSet $true).ExitCode | Should -Be 0
    }

    It "Remediate fails with an invalid SetName" {
        $Result = Invoke-TestScript -Kind Remediate -SetName "Team [IT]" -Favorites $FavoritesA
        $Result.ExitCode | Should -Be 1
        $Result.Output | Should -Match "Invalid SetName"
    }
}

Describe "Integration test helper" {
    It "New-ScriptCopy replaces only the given parameters" {
        $Temp = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("EmfHelper_{0}.ps1" -f [guid]::NewGuid().ToString("N"))
        try {
            New-ScriptCopy -Source $RemediateSource -Destination $Temp -Overrides @{
                SetName        = '"Copy"'
                Favorites      = '@(@{ Path = ""; Name = "X"; Url = "https://x.example" })'
                EdgePolicyPath = '"HKLM:\SOFTWARE\Test\Edge"'
            }
            $Tokens = $null
            $Errors = $null
            $Ast = [System.Management.Automation.Language.Parser]::ParseFile($Temp, [ref]$Tokens, [ref]$Errors)
            $Errors.Count | Should -Be 0
            $Values = @{}
            foreach ($Statement in $Ast.EndBlock.Statements) {
                if ($Statement -is [System.Management.Automation.Language.AssignmentStatementAst] -and $Statement.Left -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $Values[$Statement.Left.VariablePath.UserPath] = $Statement.Right.Extent.Text
                }
            }
            $Values["SetName"] | Should -BeExactly '"Copy"'
            $Values["EdgePolicyPath"] | Should -BeExactly '"HKLM:\SOFTWARE\Test\Edge"'
            $Values["Favorites"] | Should -BeExactly '@(@{ Path = ""; Name = "X"; Url = "https://x.example" })'
            $Values["EdgePolicyName"] | Should -BeExactly '"ManagedFavorites"'
            $Values["RegistryBasePath"] | Should -BeExactly '"HKLM:\SOFTWARE\YourCompany\EdgeManagedFavorites"'
            [System.IO.File]::ReadAllBytes($Temp)[0..2] | Should -Be @(0xEF, 0xBB, 0xBF)
        }
        finally {
            if (Test-Path -LiteralPath $Temp) { Remove-Item -LiteralPath $Temp -Force }
        }
    }
}
