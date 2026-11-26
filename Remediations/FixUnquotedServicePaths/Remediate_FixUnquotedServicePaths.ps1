<#
    Script:      Remediate_FixUnquotedServicePaths.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Puts quotes around the executable part of unquoted service paths, for example
                 C:\Program Files\Vendor App\service.exe -k
                 becomes
                 "C:\Program Files\Vendor App\service.exe" -k
                 Arguments and the value type (REG_SZ or REG_EXPAND_SZ) stay as they are.
                 Only paths whose executable exists are changed. Old and new values are logged.
#>

# ==== Parameters ====
# Must match the value in Detect_FixUnquotedServicePaths.ps1
$ServicesPath = "HKLM:\SYSTEM\CurrentControlSet\Services"
# IME log folder, so the log is part of "Collect diagnostics" in the Intune admin center
$LogFile      = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\FixUnquotedServicePaths.log"
$MaxLogSizeKB = 1024

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
$LogFolder = Split-Path -Path $LogFile -Parent
if (-not (Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}
# Keep one old log, so the transcript does not grow forever
if ((Test-Path -LiteralPath $LogFile) -and (Get-Item -LiteralPath $LogFile).Length -gt ($MaxLogSizeKB * 1KB)) {
    Move-Item -LiteralPath $LogFile -Destination "$LogFile.old" -Force -ErrorAction SilentlyContinue
}
Start-Transcript -Path $LogFile -Append | Out-Null
$ExitCode = 0
try {
    $Findings = @(Get-UnquotedServicePaths)
    $Failed = 0
    foreach ($Item in $Findings) {
        # Step 1: Write the quoted path with the original value type
        try {
            $Key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SYSTEM\CurrentControlSet\Services\$($Item.Name)", $true)
            $Key.SetValue("ImagePath", $Item.NewValue, $Item.Kind)
            $Key.Close()
            Write-Output "Fixed: $($Item.Name)"
            Write-Output "  old: $($Item.OldValue)"
            Write-Output "  new: $($Item.NewValue)"
        }
        catch {
            Write-Output "Error: $($Item.Name), $($_.Exception.Message)"
            $Failed++
        }
    }

    if ($Failed -gt 0) {
        throw "$Failed of $($Findings.Count) service path(s) could not be fixed"
    }
    Write-Output "Remediated: $($Findings.Count) unquoted service path(s) fixed"
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    $ExitCode = 1
}

Stop-Transcript | Out-Null
exit $ExitCode
