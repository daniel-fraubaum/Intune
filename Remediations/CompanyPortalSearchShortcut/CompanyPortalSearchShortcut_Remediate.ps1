<#
    Script:      CompanyPortalSearchShortcut_Remediate.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-23
    Description: Creates an English-named Company Portal shortcut in the All Users Start Menu,
                 so Start search finds "Intune" and "Company Portal" on non-English clients.
#>

# ==== Parameters ====
$ShortcutName        = "Intune Company Portal"
$AppUserModelId      = "Microsoft.CompanyPortal_8wekyb3d8bbwe!App"
$StartMenuPath       = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
$UseExplorerFallback = $false   # Set to $true if the direct shell:AppsFolder target does not work on your clients

# ==== Logic ====
try {
    # Step 1: Make sure the Start Menu folder exists
    if (-not (Test-Path -Path $StartMenuPath)) {
        New-Item -Path $StartMenuPath -ItemType Directory -Force | Out-Null
    }

    # Step 2: Create or overwrite the shortcut
    $ShortcutFile = Join-Path $StartMenuPath "$ShortcutName.lnk"
    $WshShell     = New-Object -ComObject WScript.Shell
    $Shortcut     = $WshShell.CreateShortcut($ShortcutFile)

    # Step 3: Point the shortcut to the Company Portal app
    if ($UseExplorerFallback) {
        $Shortcut.TargetPath = "$env:WINDIR\explorer.exe"
        $Shortcut.Arguments  = "shell:AppsFolder\$AppUserModelId"
    }
    else {
        $Shortcut.TargetPath = "shell:AppsFolder\$AppUserModelId"
        $Shortcut.Arguments  = ""
    }

    $Shortcut.Description = $ShortcutName
    $Shortcut.Save()

    Write-Output "Shortcut created: $ShortcutFile"
    exit 0
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
