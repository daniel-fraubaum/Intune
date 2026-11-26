
# Intune Remediation: Show File Extensions

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.0**  
Last update: **2026-11-18**

This folder contains an **Intune Remediation** pair that makes File Explorer show the file extensions of known file types (`report.pdf` instead of `report`).  
Visible extensions make it easier for users to spot disguised files such as `invoice.pdf.exe`.

---

## What this package does

- Sets `HideFileExt` to `0` for the signed-in user, so File Explorer shows extensions for known file types
- Runs in the **user context**, because the setting lives in `HKCU`
- Re-enforces the setting on every run if the user turns it off again

| Registry key | Value | Type | Data |
| --- | --- | --- | --- |
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `HideFileExt` | `REG_DWORD` | `0` = show extensions, `1` = hide extensions (Windows default) |

---

## Files

- `Detect_ShowFileExtensions.ps1`  
  Detection script. Returns exit code `0` if `HideFileExt` is `0`, `1` if it has another value or is missing.

- `Remediate_ShowFileExtensions.ps1`  
  Remediation script. Creates the key if needed and sets `HideFileExt` to `0`.

---

## Why a remediation

There is **no CSP and no Settings Catalog setting** that shows file extensions in File Explorer. The only way to set it is the per-user registry value, so a remediation that runs as the signed-in user is the simplest way to deploy and keep it.

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create**

2. **Settings**  
   - Detection script file: `Detect_ShowFileExtensions.ps1`  
   - Remediation script file: `Remediate_ShowFileExtensions.ps1`  
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
- **Users can turn it off again** in File Explorer (View → Show → File name extensions). The next remediation run sets it back.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
