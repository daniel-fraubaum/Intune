# Intune Remediation: Company Portal Search Shortcut

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.0**  
Last update: **2026-11-23**

This folder contains an **Intune Remediation** pair that makes the Company Portal findable in Windows Start search on non-English clients.  
On a German Windows the app is only called **Unternehmensportal**, so users who type `Company Portal` or `Intune` get nothing. The same happens in every other display language.

---

## What this package does

- Creates the shortcut `Intune Company Portal.lnk` in the **All Users** Start Menu (`%ProgramData%\Microsoft\Windows\Start Menu\Programs`)
- The shortcut starts the Company Portal app through its AUMID `Microsoft.CompanyPortal_8wekyb3d8bbwe!App`
- Start search matches on word beginnings, so the one shortcut is found with `intune`, `company` and `portal`
- Skips devices where the Company Portal is not installed
- Recreates the shortcut on every run if it was deleted or changed

---

## Files

- `CompanyPortalSearchShortcut_Detect.ps1`  
  Detection script. Returns exit code `0` if the shortcut exists and points to the Company Portal (or the app is not installed), `1` otherwise.

- `CompanyPortalSearchShortcut_Remediate.ps1`  
  Remediation script. Creates or overwrites the shortcut.

---

## Why a remediation

Start search finds packaged apps only by their **localized display name**. There is no keyword or alias property for Store apps, and there is **no CSP and no Settings Catalog setting** for it. What Start search does index are `.lnk` files in the Start Menu Programs folders, so an extra shortcut with an English name is the simplest way to steer it.

---

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `$ShortcutName` | `Intune Company Portal` | Name of the shortcut, this is what Start search matches on. Must be the same in both scripts |
| `$AppUserModelId` | `Microsoft.CompanyPortal_8wekyb3d8bbwe!App` | AUMID of the Company Portal app. Must be the same in both scripts |
| `$StartMenuPath` | `%ProgramData%\...\Start Menu\Programs` | All Users Start Menu folder. Must be the same in both scripts |
| `$PackageName` | `Microsoft.CompanyPortal` | Detection only. Used to skip devices without Company Portal |
| `$UseExplorerFallback` | `$false` | Remediation only. `$true` starts the app through `explorer.exe shell:AppsFolder\...` instead of targeting the app directly. Works everywhere, but the shortcut shows the Explorer icon |

You can check the AUMID on a client with:

```powershell
Get-StartApps | Where-Object Name -like "*portal*"
```

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create**

2. **Settings**  
   - Detection script file: `CompanyPortalSearchShortcut_Detect.ps1`  
   - Remediation script file: `CompanyPortalSearchShortcut_Remediate.ps1`  
   - Run this script using the logged-on credentials: **No** (runs as SYSTEM)  
   - Enforce script signature check: **No**  
   - Run script in 64-bit PowerShell: **Yes**

3. **Assignments**  
   - Assign to the device groups in scope

4. **Schedule**  
   - **Daily**

---

## Notes

- **Two entries in All apps.** Users see both `Intune Company Portal` and `Unternehmensportal` in the app list. Both open the same app.
- **Icon.** With the direct `shell:AppsFolder` target Windows should show the Company Portal icon. If your clients show a blank or wrong icon, test with `$UseExplorerFallback = $true`.
- **Search delay.** A new shortcut can take a few seconds until Start search picks it up.
- **Windows 10.** Some Windows 10 builds had a known issue where Start search did not return `.lnk` files at all. Windows 11 is not affected.
- **Removal.** Unassigning the remediation does not delete the shortcut. Remove `Intune Company Portal.lnk` from the All Users Start Menu if you want it gone.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
