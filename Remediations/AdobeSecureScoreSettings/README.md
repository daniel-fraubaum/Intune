# Intune Remediation: Adobe Secure Score Settings

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.0**  
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
| Acrobat Reader | 2017 | `bDisableJavaScript` | `1` | JavaScript in PDFs is disabled |
| Adobe Acrobat | 2017 | `bDisableJavaScript` | `1` | JavaScript in PDFs is disabled |
| Acrobat | 2017 | `bDisableJavaScript` | `1` | Same as above, under the short product name (see Notes) |

All values are `REG_DWORD` and are written to both policy paths:

```
HKLM\SOFTWARE\Policies\Adobe\<Product>\<Version>\FeatureLockDown
HKLM\SOFTWARE\WOW6432Node\Policies\Adobe\<Product>\<Version>\FeatureLockDown
```

Adobe documents the `WOW6432Node` path for 64-bit Windows, while the current 64-bit Acrobat and Reader builds read the path without it. Writing both covers 32-bit and 64-bit installations.

The values are set on every device in scope, also where Adobe is not installed yet. They take effect as soon as Acrobat or Reader is installed.

---

## Files

- `AdobeSecureScoreSettings_Detect.ps1`  
  Detection script. Returns exit code `0` if every value exists as `REG_DWORD` with the right data in both paths, `1` otherwise.

- `AdobeSecureScoreSettings_Remediate.ps1`  
  Remediation script. Creates missing keys and writes all values.

---

## Why a remediation

Intune has **no Settings Catalog setting** for these Adobe policies. The values are plain registry policies, so a remediation that writes and checks them daily is the simplest way, and it also covers the 32-bit path.

---

## Parameters

| Parameter | Description |
| --- | --- |
| `$Settings` | List of the lockdown values (product, version, value name, data). Add or remove entries here. Must be the same in both scripts |
| `$PolicyRoots` | The two policy paths (64-bit and `WOW6432Node`). Must be the same in both scripts |

Adobe reference for the values: [Preference Reference, Privileged](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/Privileged.html) and [glossary](https://www.adobe.com/devnet-docs/acrobatetk/tools/PrefRef/Windows/glossary.html).

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
reg query "HKLM\SOFTWARE\WOW6432Node\Policies\Adobe\Acrobat Reader\DC\FeatureLockDown"
```

In Reader or Acrobat, **Preferences > Security (Enhanced) > Enable Protected Mode at startup** is checked and greyed out. **Preferences > JavaScript > Enable Acrobat JavaScript** is unchecked and greyed out.

Secure Score and the Defender recommendations update with a delay after the values are set.

---

## Notes

- **JavaScript off breaks some forms.** PDF forms that calculate fields or check input with JavaScript stop working. Test with your own forms before you roll this out broadly. Remove the `bDisableJavaScript` entries from `$Settings` in both scripts if you need JavaScript.
- **Protected Mode** is the Adobe default (`1`). This package locks it, so users cannot turn it off. If you use Adobe plugins, test them with Protected Mode as well.
- **Flash.** Flash reached end of life in 2020. The value is kept from the original script, it does no harm.
- **Product name `Acrobat\2017`.** Adobe documents the product names `Adobe Acrobat` and `Acrobat Reader`. The short `Acrobat\2017` path comes from the original script and is kept next to the documented `Adobe Acrobat\2017`, an extra policy value does no harm.
- **Removal.** Unassigning the remediation does not remove the values. Delete the values or the `FeatureLockDown` keys in both paths if you want to revert.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
