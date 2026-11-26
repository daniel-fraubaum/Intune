<#
    Script:      Detect_FixUnquotedServicePaths.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Detects services whose ImagePath starts with an unquoted executable path that
                 contains a space (unquoted service path), for example
                 C:\Program Files\Vendor App\service.exe -k
                 Only paths whose executable exists are reported, so every finding can be fixed.
                 Exit 0 = compliant, exit 1 = remediation required.
#>

# ==== Parameters ====
# Must match the value in Remediate_FixUnquotedServicePaths.ps1
$ServicesPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

# ==== Functions ====
function Get-UnquotedServicePaths {
    foreach ($Key in Get-ChildItem -LiteralPath $ServicesPath -ErrorAction Stop) {
        $ImagePath = $Key.GetValue("ImagePath", $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if (-not $ImagePath) { continue }
        $Value = "$ImagePath".Trim()
        if ($Value.StartsWith('"')) { continue }

        # Executable part: the first ".exe" followed by a space or the end that points to an existing file
        $Exe = $null
        $Arguments = ""
        foreach ($Match in [regex]::Matches($Value, '\.exe(?=\s|$)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $Candidate = $Value.Substring(0, $Match.Index + 4)
            if (Test-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($Candidate)) -PathType Leaf) {
                $Exe = $Candidate
                $Arguments = $Value.Substring($Match.Index + 4)
                break
            }
        }
        if (-not $Exe -or $Exe -notmatch '\s') { continue }

        [pscustomobject]@{
            Name     = $Key.PSChildName
            Kind     = $Key.GetValueKind("ImagePath")
            OldValue = $ImagePath
            NewValue = '"' + $Exe + '"' + $Arguments
        }
    }
}

# ==== Logic ====
try {
    $Findings = @(Get-UnquotedServicePaths)
    if ($Findings.Count -gt 0) {
        Write-Output "Not compliant: $($Findings.Count) unquoted service path(s): $(($Findings | ForEach-Object { $_.Name }) -join ', ')"
        exit 1
    }

    Write-Output "Compliant: no unquoted service paths"
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
