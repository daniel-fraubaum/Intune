<#
    Script:      CompanyPortalSearchShortcut_Detect.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-23
    Description: Detects whether an English-named Company Portal shortcut exists in the All Users
                 Start Menu, so Start search finds "Intune" and "Company Portal" on non-English clients.
#>

# ==== Parameters ====
$ShortcutName   = "Intune Company Portal"
$PackageName    = "Microsoft.CompanyPortal"
$AppUserModelId = "Microsoft.CompanyPortal_8wekyb3d8bbwe!App"
$StartMenuPath  = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"

# ==== Logic ====
try {
    # Step 1: Skip devices without Company Portal
    $Package = Get-AppxPackage -AllUsers -Name $PackageName -ErrorAction SilentlyContinue
    if (-not $Package) {
        Write-Output "Compliant: $PackageName not installed, nothing to do"
        exit 0
    }

    # Step 2: Check that the shortcut exists
    $ShortcutFile = Join-Path $StartMenuPath "$ShortcutName.lnk"
    if (-not (Test-Path -Path $ShortcutFile)) {
        Write-Output "Not compliant: $ShortcutFile missing"
        exit 1
    }

    # Step 3: Check that the shortcut points to the Company Portal app
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutFile)
    if (("$($Shortcut.TargetPath) $($Shortcut.Arguments)") -notlike "*$AppUserModelId*") {
        Write-Output "Not compliant: shortcut target is incorrect"
        exit 1
    }

    Write-Output "Compliant: $ShortcutFile present and correct"
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
