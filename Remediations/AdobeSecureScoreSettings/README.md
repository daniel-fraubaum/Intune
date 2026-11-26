# 🛡️ AdobeSecureScoreSettings

Microsoft Secure Score and Defender Vulnerability Management recommend three security settings for Adobe Acrobat and Acrobat Reader: **Flash off**, **JavaScript off** and **Protected Mode on**. Intune has no Settings Catalog setting for these Adobe policies.

This remediation writes the values as lockdown policies (`FeatureLockDown`) and checks them daily. Users cannot turn them back on in the Adobe preferences.

## ✨ Features

- Sets Flash off, JavaScript off and Protected Mode on for Acrobat Reader DC and Adobe Acrobat DC
- Writes the values as `FeatureLockDown` policies, so the options are greyed out in the Adobe preferences
- One registry path covers 32-bit and 64-bit Acrobat and Reader
- Sets the values on every device in scope, also where Adobe is not installed yet. They take effect as soon as Acrobat or Reader is installed
- Checks the value type as well: a value with the right data but the wrong type (not `REG_DWORD`) is rewritten
- Creates missing keys without emptying existing ones
- Logs every value (`OK` or `Set` with the old value) to the IME log folder, so **Collect diagnostics** picks it up

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | Checks every entry in `$Settings`: the `FeatureLockDown` key exists, the value exists as `REG_DWORD` and has the right data |
| 2 | Detect | Exit `0` if all values are correct. Otherwise exit `1` and the output lists the missing or wrong values |
| 3 | Remediate | Creates the `FeatureLockDown` key if it is missing |
| 4 | Remediate | Writes every missing or wrong value as `REG_DWORD` and logs it with the old value. Correct values are logged as `OK` and left alone |

### Values

| Product | Version | Value | Data | Effect |
|---|---|---|---|---|
| Acrobat Reader | DC | `bEnableFlash` | `0` | Flash content in PDFs is not played |
| Acrobat Reader | DC | `bDisableJavaScript` | `1` | JavaScript in PDFs is disabled |
| Acrobat Reader | DC | `bProtectedMode` | `1` | Protected Mode (sandbox) is enabled and locked |
| Adobe Acrobat | DC | `bDisableJavaScript` | `1` | JavaScript in PDFs is disabled |
| Adobe Acrobat | DC | `bProtectedMode` | `1` | Protected Mode (sandbox) is enabled and locked |

All values are `REG_DWORD` under:

```
HKLM\SOFTWARE\Policies\Adobe\<Product>\<Version>\FeatureLockDown
```

Adobe documents the path as `HKLM\SOFTWARE\WOW6432Node\Policies\Adobe\...`. That is the same key: `HKLM\SOFTWARE\Policies` is [shared between the 32-bit and 64-bit registry view](https://learn.microsoft.com/windows/win32/winprog64/shared-registry-keys), so 32-bit and 64-bit Acrobat and Reader both read the values from this one path.

Adobe reference for the values: [Preference Reference, Privileged](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/Privileged.html), [JavaScript](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/JSPrefs.html) and [glossary](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/glossary.html).

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows 10 or Windows 11 |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | SYSTEM |
| Adobe | Acrobat Reader DC or Adobe Acrobat DC (Continuous track). Not required at deployment time, the values apply once Adobe is installed |

## 🔧 Configuration

Adjust the Parameters block at the top of the scripts before you upload them.

| Variable | Default | Description |
|---|---|---|
| `$Settings` | The five entries in the [values table](#values) | List of the lockdown values (product, version, value name, data). Add or remove entries here. Must be the same in both scripts |
| `$PolicyRoot` | `HKLM:\SOFTWARE\Policies\Adobe` | Policy path. Must be the same in both scripts |
| `$LogFile` | `%ProgramData%\Microsoft\IntuneManagementExtension\Logs\AdobeSecureScoreSettings.log` | Transcript of the remediation (remediation script only). In the IME log folder, so **Collect diagnostics** includes it |
| `$MaxLogSizeKB` | `1024` | Above this size the log is renamed to `.log.old` (remediation script only) |

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

| Setting | Value |
|---|---|
| Detection script file | `Detect_AdobeSecureScoreSettings.ps1` |
| Remediation script file | `Remediate_AdobeSecureScoreSettings.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups in scope |
| Schedule | Daily |

## 🧪 Testing

1. Run `Remediate_AdobeSecureScoreSettings.ps1` in an elevated 64-bit PowerShell.
2. Check the values:

   ```
   reg query "HKLM\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
   reg query "HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
   ```

3. Run `Detect_AdobeSecureScoreSettings.ps1`. It returns `Compliant: all 5 Adobe lockdown values are set`.
4. In Reader or Acrobat, **Preferences > Security (Enhanced) > Enable Protected Mode at startup** is checked and greyed out. **Preferences > JavaScript > Enable Acrobat JavaScript** is unchecked and greyed out.

Secure Score and the Defender recommendations update with a delay after the values are set.

## 📝 Logging

| Log | Location |
|---|---|
| Remediation transcript | `%ProgramData%\Microsoft\IntuneManagementExtension\Logs\AdobeSecureScoreSettings.log`, appended on every run, one line per value: `OK` or `Set` with the old value. Above `$MaxLogSizeKB` the log is renamed to `AdobeSecureScoreSettings.log.old` |
| Remote | Intune admin center > device > **Collect diagnostics**. The IME log folder is part of the collection, so the transcript (and `.log.old`) is in the downloaded zip |
| Detection | Pre-remediation output in the Intune admin center (device status of the remediation), lists the missing or wrong values |

| Exit code | Meaning |
|---|---|
| `0` | Detect: all values are set. Remediate: all values written |
| `1` | Detect: at least one value is missing or wrong, or the check failed. Remediate: a key or value could not be written |

## ⚠️ Good to know

- **JavaScript off breaks some forms.** PDF forms that calculate fields or check input with JavaScript stop working. Test with your own forms before you roll this out broadly. Remove the `bDisableJavaScript` entries from `$Settings` in both scripts if you need JavaScript.
- **Protected Mode** is the Adobe default (`1`). This package locks it, so users cannot turn it off. If you use Adobe plugins, test them with Protected Mode as well.
- **Flash** reached end of life in 2020. The value is kept from the original script, it does no harm.
- **Classic track.** Only the DC (Continuous) track is covered. Acrobat and Reader 2017 are out of support since June 2022, so their entries are no longer in `$Settings`. If you still run a Classic version, add entries with its version (for example `2020`) to `$Settings` in both scripts.
- **Old 2017 keys.** An earlier version of this package also wrote `Acrobat Reader\2017`, `Adobe Acrobat\2017` and `Acrobat\2017`. The current scripts leave them in place, they do no harm. Delete the `2017` keys under `HKLM\SOFTWARE\Policies\Adobe` if you want to clean up.
- **Why a remediation.** Intune has no Settings Catalog setting for these Adobe policies. The values are plain registry policies, so a remediation that writes and checks them daily is the simplest way.
- **Removal.** Unassigning the remediation does not remove the values. Delete the values or the `FeatureLockDown` keys if you want to revert.

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
