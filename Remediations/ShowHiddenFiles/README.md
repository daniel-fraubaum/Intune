
# Intune Remediation: Show Hidden Files

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.0**  
Last update: **2026-11-18**

This folder contains an **Intune Remediation** pair that makes File Explorer show hidden files and folders, such as `AppData` in the user profile.

---

## What this package does

- Sets `Hidden` to `1` for the signed-in user, so File Explorer shows hidden files and folders
- Runs in the **user context**, because the setting lives in `HKCU`
- Re-enforces the setting on every run if the user turns it off again
- Does **not** touch protected operating system files (`ShowSuperHidden`). Those stay hidden on purpose

| Registry key | Value | Type | Data |
| --- | --- | --- | --- |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Hidden` | `REG_DWORD` | `1` = show hidden files, `2` = hide hidden files (Windows default) |

---

## Files

- `Detect_ShowHiddenFiles.ps1`  
  Detection script. Returns exit code `0` if `Hidden` is `1`, `1` if it has another value or is missing.

- `Remediate_ShowHiddenFiles.ps1`  
  Remediation script. Creates the key if needed and sets `Hidden` to `1`.

---

## Why a remediation

There is **no CSP and no Settings Catalog setting** that shows hidden files in File Explorer. The only way to set it is the per-user registry value, so a remediation that runs as the signed-in user is the simplest way to deploy and keep it.

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create**

2. **Settings**  
   - Detection script file: `Detect_ShowHiddenFiles.ps1`  
   - Remediation script file: `Remediate_ShowHiddenFiles.ps1`  
   - Run this script using the logged-on credentials: **Yes**  
   - Enforce script signature check: **No**  
   - Run script in 64-bit PowerShell: **Yes**

3. **Assignments**  
   - Assign to the user or device groups in scope

4. **Schedule**  
   - **Daily**

---

## Notes

- **Open Explorer windows** do not pick up the change right away. Press **F5** or close and reopen the window.
- **Users can turn it off again** in File Explorer (View → Show → Hidden items). The next remediation run sets it back.
- **Protected operating system files** (`ShowSuperHidden`) are intentionally left alone. Showing them only adds clutter and makes it easier to delete system files by accident.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
