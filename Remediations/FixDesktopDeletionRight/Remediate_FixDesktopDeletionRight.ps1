<#
    Script:      Remediate_FixDesktopDeletionRight.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Grants standard users (BUILTIN\Users, S-1-5-32-545) only the right "Delete subfolders
                 and files" (DC) on the Public Desktop folder itself, so they can delete shortcuts
                 that installers place there for all users.
                 Users can delete items, but cannot create, change or re-permission them.
                 Any other explicit Users right on the folder is removed first (for example
                 FullControl from version 1.0). No /T, so junctions are never followed.
#>

# ==== Parameters ====
# Must match the value in Detect_FixDesktopDeletionRight.ps1
$UsersSid      = "S-1-5-32-545"
# IME log folder, so the log is part of "Collect diagnostics" in the Intune admin center
$LogFile       = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\FixDesktopDeletionRight.log"
$MaxLogSizeKB  = 1024

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
    # Step 1: Locate the Public Desktop
    $DesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
    if (-not $DesktopPath -or -not (Test-Path -LiteralPath $DesktopPath)) {
        throw "Public Desktop not found"
    }

    # Step 2: Never set permissions through a junction or symbolic link
    $Folder = Get-Item -LiteralPath $DesktopPath -Force -ErrorAction Stop
    if ($Folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        throw "$DesktopPath is a junction or symbolic link, not touched"
    }

    # Step 3: Remove all explicit Users rights on the folder, then grant DC only
    # (/grant:r is not enough: it only replaces entries with the same inheritance flags)
    foreach ($IcaclsArgs in @(
            @("/remove:g", "*$UsersSid"),
            @("/grant", "*$($UsersSid):(DC)")
        )) {
        Write-Output "Running: icacls `"$DesktopPath`" $($IcaclsArgs -join ' ')"
        $Output = & "$env:SystemRoot\System32\icacls.exe" $DesktopPath @IcaclsArgs 2>&1
        $IcaclsExitCode = $LASTEXITCODE
        $Output | Where-Object { "$_".Trim() } | ForEach-Object { Write-Output "$_" }
        if ($IcaclsExitCode -ne 0) {
            throw "icacls $($IcaclsArgs[0]) failed with exit code $IcaclsExitCode"
        }
    }

    # Step 4: Log the resulting Users rules (from .NET, so no icacls code page issues)
    (Get-Acl -LiteralPath $DesktopPath).GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier]) |
        Where-Object { $_.IdentityReference.Value -eq $UsersSid } |
        ForEach-Object { Write-Output "Users rule: $($_.AccessControlType) $($_.FileSystemRights) Inherited=$($_.IsInherited)" }

    Write-Output "Remediated: Users have Delete subfolders and files (DC) on $DesktopPath"
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    $ExitCode = 1
}

Stop-Transcript | Out-Null
exit $ExitCode
