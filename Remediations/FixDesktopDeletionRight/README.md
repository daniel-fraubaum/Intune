# Intune Remediation: Fix Desktop Deletion Right

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.0**  
Last update: **2026-11-26**

This folder contains an **Intune Remediation** pair that lets standard users delete shortcuts from their desktop that installers placed there for **all users**.  
Many installers (browsers, Teams, Adobe, VPN clients and more) put their shortcut on the **Public Desktop** (`C:\Users\Public\Desktop`). Every user sees it on the desktop, but by default only administrators may change that folder. A standard user who deletes such a shortcut gets *"You need administrator permission to delete this file"*.

---

## What this package does

- Grants **BUILTIN\Users** (SID `S-1-5-32-545`) **Full Control** on the Public Desktop
- The permission is inherited to subfolders and files `(OI)(CI)`, so shortcuts that installers add later can be deleted as well
- Applies the permission to all existing items (`/T`), including items with broken inheritance
- Uses the SID instead of the group name, so it works on every display language (`Users`, `Benutzer`, `Utilisateurs`, ...)
- Finds the Public Desktop through Windows (`CommonDesktopDirectory`) instead of a fixed path
- Re-applies the permission on every run if something removed it

---

## Files

- `FixDesktopDeletionRight_Detect.ps1`  
  Detection script. Returns exit code `0` if Users have the right on the Public Desktop (inherited to subfolders and files) and on every item in it, `1` otherwise.

- `FixDesktopDeletionRight_Remediate.ps1`  
  Remediation script. Runs `icacls` on the Public Desktop and logs the result.

The remediation runs this command:

```
icacls "C:\Users\Public\Desktop" /grant *S-1-5-32-545:(OI)(CI)F /T /C
```

---

## Why a remediation

There is **no CSP and no Settings Catalog setting** for file system permissions on Windows client folders. The default permissions of `C:\Users\Public\Desktop` come with Windows, so a remediation that sets them once and checks them daily is the simplest way.

---

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `$Rights` | `FullControl` | Right for Users: `FullControl` or `Modify`. Must be the same in both scripts |
| `$UsersSid` | `S-1-5-32-545` | SID of `BUILTIN\Users`. Must be the same in both scripts |
| `$LogFile` | `C:\Windows\Logs\FixDesktopDeletionRight.log` | Transcript of the remediation (remediation script only) |

---

## Security considerations

> Important  
> Every user of the device can then **add, change and delete** shortcuts on the Public Desktop, and every other user sees them.

- On **shared devices** a user could change the target of a shortcut that other users, including administrators, click. Think twice before you assign this to shared or kiosk devices.
- `Modify` is enough to delete shortcuts. `FullControl` additionally lets users change permissions and take ownership of the items. Set `$Rights = "Modify"` in both scripts if you only want to allow deleting.

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create**

2. **Settings**  
   - Detection script file: `FixDesktopDeletionRight_Detect.ps1`  
   - Remediation script file: `FixDesktopDeletionRight_Remediate.ps1`  
   - Run this script using the logged-on credentials: **No** (runs as SYSTEM)  
   - Enforce script signature check: **No**  
   - Run script in 64-bit PowerShell: **Yes**

3. **Assignments**  
   - Assign to the device groups in scope (personal devices, see **Security considerations**)

4. **Schedule**  
   - **Daily**

---

## Testing

Run the remediation as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt, then check the permissions:

```
psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\FixDesktopDeletionRight_Remediate.ps1
```

```
icacls "C:\Users\Public\Desktop"
```

The output contains `BUILTIN\Users:(OI)(CI)(F)` (`VORDEFINIERT\Benutzer:(OI)(CI)(F)` on a German Windows). A standard user can now delete a shortcut from the Public Desktop without an admin prompt.

---

## Logs

| Log | Location |
| --- | --- |
| Remediation transcript | `C:\Windows\Logs\FixDesktopDeletionRight.log` (appended on every run, includes the `icacls` output) |
| Detection | Output in the Intune admin center (device status of the remediation) |

---

## Notes

- **Shortcuts come back.** Updates of some apps put their shortcut on the Public Desktop again. That is the installer, not this remediation. Users can delete it again.
- **Removal.** Unassigning the remediation does not remove the permission. To go back to the Windows default (read and execute), run `icacls "C:\Users\Public\Desktop" /grant:r *S-1-5-32-545:(OI)(CI)RX /T`. Do not use `/remove`, that would also remove the read access Users need to see the shortcuts.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
