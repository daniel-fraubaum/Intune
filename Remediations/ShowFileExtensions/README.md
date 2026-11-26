# 🏷️ ShowFileExtensions

By default File Explorer hides the extensions of known file types, so users see `report` instead of `report.pdf`. That makes disguised files such as `invoice.pdf.exe` hard to spot.

This remediation makes File Explorer show file extensions for the signed-in user and sets it back on every run if the user turns it off.

## ✨ Features

- Sets `HideFileExt` to `0` for the signed-in user, so File Explorer shows extensions for known file types
- Runs in the **user context**, because the setting lives in `HKCU`
- Creates the registry key if it is missing
- Re-enforces the setting on every run if the user turns it off again

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | Reads `HideFileExt`. Exit `0` if it is `0`, exit `1` if it has another value or is missing |
| 2 | Remediate | Creates the key if needed and sets `HideFileExt` to `0` as `REG_DWORD` |

| Registry key | Value | Type | Data |
|---|---|---|---|
| `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` | `HideFileExt` | `REG_DWORD` | `0` = show extensions, `1` = hide extensions (Windows default) |

### Why a remediation

There is **no CSP and no Settings Catalog setting** that shows file extensions in File Explorer. The only way to set it is the per-user registry value, so a remediation that runs as the signed-in user is the simplest way to deploy and keep it.

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
| Detection script file | `Detect_ShowFileExtensions.ps1` |
| Remediation script file | `Remediate_ShowFileExtensions.ps1` |
| Run this script using the logged-on credentials | Yes (signed-in user) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | User groups or device groups in scope |
| Schedule | Daily |

## 🧪 Testing

1. Sign in as a standard user and run `Remediate_ShowFileExtensions.ps1` in a normal (not elevated) PowerShell.
2. Check the value:

   ```
   reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt
   ```

   It shows `0x0`.
3. Run `Detect_ShowFileExtensions.ps1`. It returns `Compliant: HideFileExt is 0`.
4. Open File Explorer (or press **F5** in an open window). Files show their extensions, for example `report.pdf`.

## 📝 Logging

The scripts write no log file. The output is in the Intune admin center, device status of the remediation (pre-remediation detection output and remediation output).

| Exit code | Meaning |
|---|---|
| `0` | Detect: `HideFileExt` is `0`. Remediate: value set |
| `1` | Detect: `HideFileExt` has another value or is missing. Remediate: value could not be set |

## ⚠️ Good to know

- **Open Explorer windows** do not pick up the change right away. Press **F5** or close and reopen the window.
- **Users can turn it off again** in File Explorer (**View** > **Show** > **File name extensions**). The next remediation run sets it back.
- **No user, no run.** The scripts change the profile of the signed-in user. Users who never sign in while the remediation runs do not get the setting.

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
