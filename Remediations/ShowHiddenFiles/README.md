# 👁️ ShowHiddenFiles

By default File Explorer hides hidden files and folders, such as `AppData` in the user profile. Users and support staff then cannot browse to them without changing the view first.

This remediation makes File Explorer show hidden files and folders for the signed-in user and sets it back on every run if the user turns it off. Protected operating system files stay hidden.

## ✨ Features

- Sets `Hidden` to `1` for the signed-in user, so File Explorer shows hidden files and folders
- Runs in the **user context**, because the setting lives in `HKCU`
- Creates the registry key if it is missing
- Re-enforces the setting on every run if the user turns it off again
- Does **not** touch protected operating system files (`ShowSuperHidden`). Those stay hidden on purpose

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | Reads `Hidden`. Exit `0` if it is `1`, exit `1` if it has another value or is missing |
| 2 | Remediate | Creates the key if needed and sets `Hidden` to `1` as `REG_DWORD` |

| Registry key | Value | Type | Data |
|---|---|---|---|
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `Hidden` | `REG_DWORD` | `1` = show hidden files, `2` = hide hidden files (Windows default) |

### Why a remediation

There is **no CSP and no Settings Catalog setting** that shows hidden files in File Explorer. The only way to set it is the per-user registry value, so a remediation that runs as the signed-in user is the simplest way to deploy and keep it.

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows 10 or Windows 11 |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | Signed-in user (`HKCU`) |

## 🔧 Configuration

No configuration needed.

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

| Setting | Value |
|---|---|
| Detection script file | `Detect_ShowHiddenFiles.ps1` |
| Remediation script file | `Remediate_ShowHiddenFiles.ps1` |
| Run this script using the logged-on credentials | Yes (signed-in user) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | User groups or device groups in scope |
| Schedule | Daily |

## 🧪 Testing

1. Sign in as a standard user and run `Remediate_ShowHiddenFiles.ps1` in a normal (not elevated) PowerShell.
2. Check the value:

   ```
   reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden
   ```

   It shows `0x1`.
3. Run `Detect_ShowHiddenFiles.ps1`. It returns `Compliant: Hidden is 1`.
4. Open File Explorer (or press **F5** in an open window) and browse to `%USERPROFILE%`. The `AppData` folder is visible.

## 📝 Logging

The scripts write no log file. The output is in the Intune admin center, device status of the remediation (pre-remediation detection output and remediation output).

| Exit code | Meaning |
|---|---|
| `0` | Detect: `Hidden` is `1`. Remediate: value set |
| `1` | Detect: `Hidden` has another value or is missing. Remediate: value could not be set |

## ⚠️ Good to know

- **Open Explorer windows** do not pick up the change right away. Press **F5** or close and reopen the window.
- **Users can turn it off again** in File Explorer (**View** > **Show** > **Hidden items**). The next remediation run sets it back.
- **Protected operating system files** (`ShowSuperHidden`) are intentionally left alone. Showing them only adds clutter and makes it easier to delete system files by accident.
- **No user, no run.** The scripts change the profile of the signed-in user. Users who never sign in while the remediation runs do not get the setting.

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
