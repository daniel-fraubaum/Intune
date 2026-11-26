# 🔎 CompanyPortalSearchShortcut

On a non-English Windows the Company Portal app only has its localized name. On a German Windows it is called **Unternehmensportal**, so users who type `Company Portal` or `Intune` in Start search get nothing. The same happens in every other display language.

This remediation creates an English-named shortcut to the Company Portal in the All Users Start Menu. Start search indexes it, so the app is found with `intune`, `company` and `portal`.

On a German Windows 11 client, typing `company` in Start search now returns the Company Portal as best match:

![Start search for "company" finds the Company Portal on a German client](images/start-search-company.png)

## ✨ Features

- Creates the shortcut `Intune Company Portal.lnk` in the **All Users** Start Menu (`%ProgramData%\Microsoft\Windows\Start Menu\Programs`)
- The shortcut starts the Company Portal app through Explorer and its AUMID: `explorer.exe shell:AppsFolder\Microsoft.CompanyPortal_8wekyb3d8bbwe!App`
- Takes the app logo from the installed Company Portal package, converts it to `CompanyPortal.ico` and uses it as shortcut icon
- Start search matches on word beginnings, so the one shortcut is found with `intune`, `company` and `portal`
- Skips devices where the Company Portal is not installed
- Recreates the shortcut on every run if it was deleted or changed

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | Exit `0` if the Company Portal package (`Get-AppxPackage -AllUsers`) is not installed, nothing to do |
| 2 | Detect | Checks that `Intune Company Portal.lnk` exists, targets `%WINDIR%\explorer.exe` with the argument `shell:AppsFolder\<AUMID>`, and uses `CompanyPortal.ico` from `$IconFolder` as icon. Exit `1` if one check fails |
| 3 | Remediate | Finds the newest installed Company Portal package. Exit `0` if it is not installed |
| 4 | Remediate | Reads the `Square44x44Logo` from `AppxManifest.xml`, picks the largest unplated PNG (no high contrast variants) and writes it as `CompanyPortal.ico` to `$IconFolder` |
| 5 | Remediate | Deletes the old shortcut and creates a new one with `WScript.Shell`: target `explorer.exe`, argument `shell:AppsFolder\<AUMID>`, icon `CompanyPortal.ico` |

### Why a shortcut

Start search finds packaged apps only by their **localized display name**. There is no keyword or alias property for Store apps, and there is **no CSP and no Settings Catalog setting** for it. What Start search does index are `.lnk` files in the Start Menu Programs folders, so an extra shortcut with an English name is the simplest way to steer it.

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows 11. See the Windows 10 note under **Good to know** |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | SYSTEM |
| App | Company Portal (`Microsoft.CompanyPortal`) installed. Devices without it are skipped |

## 🔧 Configuration

Adjust the Parameters block at the top of the scripts before you upload them.

| Variable | Default | Description |
|---|---|---|
| `$ShortcutName` | `Intune Company Portal` | Name of the shortcut, this is what Start search matches on. Must be the same in both scripts |
| `$PackageName` | `Microsoft.CompanyPortal` | Package name, used to skip devices without Company Portal and to find the app logo. Must be the same in both scripts |
| `$AppUserModelId` | `Microsoft.CompanyPortal_8wekyb3d8bbwe!App` | AUMID of the Company Portal app. Must be the same in both scripts |
| `$StartMenuPath` | `%ProgramData%\Microsoft\Windows\Start Menu\Programs` | All Users Start Menu folder. Must be the same in both scripts |
| `$IconFolder` | `%ProgramFiles%\CompanyPortalSearchShortcut` | Folder for the extracted `CompanyPortal.ico`. Must be the same in both scripts |

You can check the AUMID on a client with:

```powershell
Get-StartApps | Where-Object Name -like "*portal*"
```

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

| Setting | Value |
|---|---|
| Detection script file | `Detect_CompanyPortalSearchShortcut.ps1` |
| Remediation script file | `Remediate_CompanyPortalSearchShortcut.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups in scope |
| Schedule | Daily |

## 🧪 Testing

1. Run the remediation as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediate_CompanyPortalSearchShortcut.ps1
   ```

2. Check that `%ProgramData%\Microsoft\Windows\Start Menu\Programs\Intune Company Portal.lnk` and `%ProgramFiles%\CompanyPortalSearchShortcut\CompanyPortal.ico` exist.
3. Run `Detect_CompanyPortalSearchShortcut.ps1` the same way. It returns `Compliant: ... present and correct`.
4. Type `company`, `intune` or `portal` in Start search. The Company Portal shows up with its own icon and opens on click.

## 📝 Logging

The scripts write no log file. The output is in the Intune admin center, device status of the remediation (pre-remediation detection output and remediation output).

| Exit code | Meaning |
|---|---|
| `0` | Detect: shortcut present and correct, or Company Portal not installed. Remediate: shortcut created, or Company Portal not installed |
| `1` | Detect: shortcut missing, wrong target, or icon missing or not set, or the check failed. Remediate: shortcut could not be created |

## ⚠️ Good to know

- **Icon in Program Files.** Standard users can create folders in `C:\ProgramData` and then own them, for example as a junction to another folder, so SYSTEM would write the icon there. `C:\Program Files` does not allow that, and the remediation never writes the icon through a junction. Earlier versions used `%ProgramFiles%\CompanyPortalSearchShortcut`. Existing shortcuts are recreated with the new icon path on the next run, the old folder can be deleted.
- **Two entries in All apps.** Users see both `Intune Company Portal` and `Unternehmensportal` in the app list. Both open the same app.
- **Why Explorer.** A shortcut that targets `shell:AppsFolder\...` directly (without `explorer.exe`) is broken when created with `WScript.Shell`: no icon, and Explorer restarts on every launch. An earlier version of this package did that. The current scripts detect such a shortcut and replace it automatically.
- **Icon cache.** If Start still shows the old icon after the update, sign out and back in.
- **Search delay.** A new shortcut can take a few seconds until Start search picks it up.
- **Windows 10.** Some Windows 10 builds had a known issue where Start search did not return `.lnk` files at all. Windows 11 is not affected.
- **Removal.** Unassigning the remediation does not delete the shortcut. Remove `Intune Company Portal.lnk` from the All Users Start Menu and the `%ProgramFiles%\CompanyPortalSearchShortcut` folder if you want it gone.

## 🛠️ Troubleshooting

| Symptom | Check |
|---|---|
| Remediation output shows `Warning: no logo found` and detection stays not compliant | The script found no logo PNG in the Company Portal package, so the shortcut has the default icon. Detection requires `CompanyPortal.ico`. Update or reinstall the Company Portal and run the remediation again |

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
