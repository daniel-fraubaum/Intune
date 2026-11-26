# Intune Remediation: Fix Desktop Deletion Right

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.1**  
Last update: **2026-11-26**

This folder contains an **Intune Remediation** pair that lets standard users delete shortcuts from their desktop that installers placed there for **all users**.  
Many installers (browsers, Teams, Adobe, VPN clients and more) put their shortcut on the **Public Desktop** (`C:\Users\Public\Desktop`). Every user sees it on the desktop, but by default only administrators may change that folder. A standard user who deletes such a shortcut gets *"You need administrator permission to delete this file"*.

---

## What this package does

- Grants **BUILTIN\Users** (SID `S-1-5-32-545`) only the right **Delete subfolders and files** (`DC`) on the Public Desktop folder
- With `DC` on a folder, Windows lets a user delete **every file in it**, whatever the permissions of the file are. Shortcuts with broken inheritance are covered too
- Users **cannot create or change** anything on the Public Desktop. They can only delete
- Removes other explicit Users rights on the folder first, for example `FullControl` from version 1.0
- Does not touch a Public Desktop that is a junction or symbolic link
- Uses the SID instead of the group name, so it works on every display language (`Users`, `Benutzer`, `Utilisateurs`, ...)
- Finds the Public Desktop through Windows (`CommonDesktopDirectory`) instead of a fixed path
- Re-applies the permission on every run if something removed it

---

## Files

- `FixDesktopDeletionRight_Detect.ps1`  
  Detection script. Returns exit code `0` if Users have `DC` on the Public Desktop and no explicit right to create items, delete the folder or change its permissions. Returns `1` otherwise.

- `FixDesktopDeletionRight_Remediate.ps1`  
  Remediation script. Runs `icacls` on the Public Desktop and logs the result.

The remediation runs these commands:

```
icacls "C:\Users\Public\Desktop" /remove:g *S-1-5-32-545
icacls "C:\Users\Public\Desktop" /grant *S-1-5-32-545:(DC)
```

`/grant:r` alone is not enough: it only replaces Users entries with the same inheritance flags, so an `(OI)(CI)(F)` entry from version 1.0 would stay.

---

## Why only "Delete subfolders and files"

Version 1.0 granted `FullControl` with `/T`. That was unsafe:

- With `FullControl` or `Modify`, any user can create a **junction** on the Public Desktop, for example to `C:\Program Files`. `icacls /T` follows junctions, so the next run as SYSTEM granted Users Full Control on the junction target. A user could then replace program files and gain SYSTEM rights.
- `icacls <file> /grant ...:(OI)(CI)F` reports success on files but changes nothing. Shortcuts with broken inheritance were never fixed, and the remediation failed every day.

`DC` on the folder itself solves both. Users cannot create a junction, and `/T` is not needed because `DC` on the parent folder covers every file.

---

## Why a remediation

There is **no CSP and no Settings Catalog setting** for file system permissions on Windows client folders. The default permissions of `C:\Users\Public\Desktop` come with Windows, so a remediation that sets them once and checks them daily is the simplest way.

---

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `$UsersSid` | `S-1-5-32-545` | SID of `BUILTIN\Users`. Must be the same in both scripts |
| `$LogFile` | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\FixDesktopDeletionRight.log` | Transcript of the remediation (remediation script only). In the IME log folder, so **Collect diagnostics** includes it |
| `$MaxLogSizeKB` | `1024` | Above this size the log is renamed to `.log.old` (remediation script only) |

---

## Security considerations

> Important  
> Every user of the device can **delete** any shortcut on the Public Desktop, and it is gone for all users.

- Users **cannot** add or change shortcuts, so they cannot change the target of a shortcut that other users or administrators click.
- On **shared devices** one user can remove a shortcut that other users still need. It comes back with the next update or reinstall of the app.

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
   - Assign to the device groups in scope

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

The output contains `BUILTIN\Users:(DC)` (`VORDEFINIERT\Benutzer:(DC)` on a German Windows). A standard user can now delete a shortcut from the Public Desktop without an admin prompt, but cannot create a file there.

---

## Logs

| Log | Location |
| --- | --- |
| Remediation transcript | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\FixDesktopDeletionRight.log` (appended on every run, includes the `icacls` output and the resulting Users rules) |
| Remote | Intune admin center → device → **Collect diagnostics**. The IME log folder is part of the collection, so the transcript (and `.log.old`) is in the downloaded zip |
| Detection | Output in the Intune admin center (device status of the remediation) |

---

## Notes

- **Shortcuts come back.** Updates of some apps put their shortcut on the Public Desktop again. That is the installer, not this remediation. Users can delete it again.
- **Subfolders.** Users can delete shortcuts and other files, but not a whole folder on the Public Desktop. Installers almost never put folders there.
- **Delete with PowerShell 7.** `Remove-Item -Force` in PowerShell 7 is denied, because `-Force` also needs to change file attributes. Explorer, the Recycle Bin, `del` and `Remove-Item` without `-Force` work.
- **Upgrade from version 1.0 or the old platform script.** If you used a platform script (Devices → Scripts) or version 1.0 with `icacls C:\Users\Public\Desktop /grant *S-1-5-32-545:(OI)(CI)F /t`, unassign it first. Otherwise new devices get `FullControl` again and the remediation removes it on the next run. Version 1.1 removes the `FullControl` entry on the Public Desktop folder itself, and with it the inherited right on all shortcuts. Subfolders on the Public Desktop that got an explicit Users right from version 1.0 (`/T`) keep it. Check them with `icacls "C:\Users\Public\Desktop\<folder>"` and remove it with `icacls "C:\Users\Public\Desktop\<folder>" /remove:g *S-1-5-32-545`.
- **Removal.** Unassigning the remediation does not remove the permission. To go back to the Windows default, run `icacls "C:\Users\Public\Desktop" /remove:g *S-1-5-32-545`. By default Windows has no Users entry on the Public Desktop. Users see the shortcuts through `NT AUTHORITY\INTERACTIVE` (read and execute), which stays in place.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
