# Intune Remediation: Adobe Secure Score Settings

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.1**  
Last update: **2026-11-26**

This folder contains an **Intune Remediation** pair that sets the Adobe Acrobat and Acrobat Reader security settings that Microsoft Secure Score and Defender Vulnerability Management recommend: **Flash off**, **JavaScript off** and **Protected Mode on**.  
The values are written as lockdown policies (`FeatureLockDown`), so users cannot turn them back on in the Adobe preferences.

---

## What this package does

| Product | Version | Value | Data | Effect |
| --- | --- | --- | --- | --- |
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

The values are set on every device in scope, also where Adobe is not installed yet. They take effect as soon as Acrobat or Reader is installed.

---

## Files

- `AdobeSecureScoreSettings_Detect.ps1`  
  Detection script. Returns exit code `0` if every value exists as `REG_DWORD` with the right data, `1` otherwise. The output lists the missing or wrong values.

- `AdobeSecureScoreSettings_Remediate.ps1`  
  Remediation script. Creates missing keys, writes missing or wrong values and logs every change.

---

## Why a remediation

Intune has **no Settings Catalog setting** for these Adobe policies. The values are plain registry policies, so a remediation that writes and checks them daily is the simplest way.

---

## Parameters

| Parameter | Default | Description |
| --- | --- | --- |
| `$Settings` | see table above | List of the lockdown values (product, version, value name, data). Add or remove entries here. Must be the same in both scripts |
| `$PolicyRoot` | `HKLM:\SOFTWARE\Policies\Adobe` | Policy path. Must be the same in both scripts |
| `$LogFile` | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AdobeSecureScoreSettings.log` | Transcript of the remediation (remediation script only). In the IME log folder, so **Collect diagnostics** includes it |
| `$MaxLogSizeKB` | `1024` | Above this size the log is renamed to `.log.old` (remediation script only) |

Adobe reference for the values: [Preference Reference, Privileged](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/Privileged.html), [JavaScript](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/JSPrefs.html) and [glossary](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/glossary.html).

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create**

2. **Settings**  
   - Detection script file: `AdobeSecureScoreSettings_Detect.ps1`  
   - Remediation script file: `AdobeSecureScoreSettings_Remediate.ps1`  
   - Run this script using the logged-on credentials: **No** (runs as SYSTEM)  
   - Enforce script signature check: **No**  
   - Run script in 64-bit PowerShell: **Yes**

3. **Assignments**  
   - Assign to the device groups in scope

4. **Schedule**  
   - **Daily**

---

## Testing

Run the remediation in an elevated PowerShell (64-bit), then check the values:

```
reg query "HKLM\SOFTWARE\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
reg query "HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\DC\FeatureLockDown"
```

In Reader or Acrobat, **Preferences > Security (Enhanced) > Enable Protected Mode at startup** is checked and greyed out. **Preferences > JavaScript > Enable Acrobat JavaScript** is unchecked and greyed out.

Secure Score and the Defender recommendations update with a delay after the values are set.

---

## Logs

| Log | Location |
| --- | --- |
| Remediation transcript | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\AdobeSecureScoreSettings.log` (appended on every run, one line per value: `OK` or `Set` with the old value) |
| Remote | Intune admin center → device → **Collect diagnostics**. The IME log folder is part of the collection, so the transcript (and `.log.old`) is in the downloaded zip |
| Detection | Output in the Intune admin center (device status of the remediation), lists the missing or wrong values |

---

## Notes

- **JavaScript off breaks some forms.** PDF forms that calculate fields or check input with JavaScript stop working. Test with your own forms before you roll this out broadly. Remove the `bDisableJavaScript` entries from `$Settings` in both scripts if you need JavaScript.
- **Protected Mode** is the Adobe default (`1`). This package locks it, so users cannot turn it off. If you use Adobe plugins, test them with Protected Mode as well.
- **Flash.** Flash reached end of life in 2020. The value is kept from the original script, it does no harm.
- **Classic track.** Only the DC (Continuous) track is covered. Acrobat and Reader 2017 are out of support since June 2022, their entries were removed in version 1.1. If you still run a Classic version, add entries with its version (for example `2020`) to `$Settings` in both scripts.
- **Upgrade from version 1.0.** Version 1.0 also wrote `Acrobat Reader\2017`, `Adobe Acrobat\2017` and `Acrobat\2017`. Version 1.1 leaves them in place, they do no harm. Delete the `2017` keys under `HKLM\SOFTWARE\Policies\Adobe` if you want to clean up.
- **Removal.** Unassigning the remediation does not remove the values. Delete the values or the `FeatureLockDown` keys if you want to revert.

---

## Changelog

| Version | Date | Change |
| --- | --- | --- |
| 1.1 | 2026-11-26 | One policy path (`WOW6432Node\Policies` is the same key), 2017 entries removed, log in the IME log folder (part of Collect diagnostics) with one line per value, detection lists all wrong values |
| 1.0 | 2026-11-26 | First version |

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
