# 🔑 SecureBootCertUpdate

The Secure Boot certificates that Microsoft issued in 2011 began to expire in June 2026. Devices without the 2023 certificates still start and get regular Windows updates, but may not get future Secure Boot protections for early boot components ([Update Secure Boot certificates](https://learn.microsoft.com/troubleshoot/windows-client/windows-security/update-secure-boot-certificates)).

This folder contains two remediations. The first opts the device in to the Microsoft managed Secure Boot certificate update by setting `MicrosoftUpdateManagedOptIn` to `1`. The second is detection only and reports whether the Windows UEFI CA 2023 update is applied, so you can follow the rollout in the Intune admin center.

## ✨ Features

- Opt-in remediation pair: sets `MicrosoftUpdateManagedOptIn` = `1` (`REG_DWORD`) under `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot`
- Creates the key if it is missing and changes the value only if it is missing or different
- Separate detection-only remediation for the Windows UEFI CA 2023 status, without a remediation script
- CA 2023 check uses the servicing status in the registry first, then the Windows UEFI CA 2023 certificate in the Secure Boot db
- Clear output for every result (registry values, certificate found or not, db not accessible)

## ⚙️ How it works

### Opt-in remediation

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | `HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\` does not exist: not compliant, exit `1` |
| 2 | Detect | `MicrosoftUpdateManagedOptIn` is `1`: compliant, exit `0`. Missing or another value: not compliant, exit `1` |
| 3 | Remediate | Creates the key if it is missing |
| 4 | Remediate | Sets `MicrosoftUpdateManagedOptIn` to `1` (`DWORD`) if it is missing or not `1`, otherwise reports that no action is required |

| Registry key | Value | Type | Data |
|---|---|---|---|
| `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot` | `MicrosoftUpdateManagedOptIn` | `REG_DWORD` | `1` |

### Windows UEFI CA 2023 detection

`Detect_SecureBootCertUpdate_UEFICA2023.ps1` reads three values under `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing`. A missing key or value counts as empty.

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | Reads `UEFICA2023Status`, `UEFICA2023Error` and `WindowsUEFICA2023Capable` |
| 2 | Detect | (`UEFICA2023Status` is `Updated` or `WindowsUEFICA2023Capable` is `2`) and (`UEFICA2023Error` is missing or `0`): compliant, exit `0` |
| 3 | Detect | Otherwise reads the Secure Boot db with `Get-SecureBootUEFI -Name db` and converts the bytes to ASCII text |
| 4 | Detect | The text contains `Windows UEFI CA 2023`: compliant, exit `0`. Otherwise: not compliant, exit `1` |
| 5 | Detect | The db cannot be read (no Secure Boot support or access denied): exit `1` |

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows Enterprise, Pro or Education, Microsoft Entra joined or Microsoft Entra hybrid joined, enrolled in Intune or co-managed |
| Firmware | UEFI with Secure Boot, so `Get-SecureBootUEFI` can read the db (CA 2023 detection) |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | SYSTEM |
| License | Remediations require Windows Enterprise E3 or E5, Windows Education A3 or A5, or Windows VDA per user |

## 🔧 Configuration

No configuration needed.

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

Create two remediations.

### Opt-in

| Setting | Value |
|---|---|
| Detection script file | `Detect_SecureBootCertUpdate_OptIn.ps1` |
| Remediation script file | `Remediate_SecureBootCertUpdate_OptIn.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups |
| Schedule | Daily |

### Windows UEFI CA 2023 status (detection only)

| Setting | Value |
|---|---|
| Detection script file | `Detect_SecureBootCertUpdate_UEFICA2023.ps1` |
| Remediation script file | None, leave it empty |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups |
| Schedule | Daily |

In the device status of this remediation, "With issues" means the CA 2023 update is not applied (or the db could not be read), "Without issues" means it is applied.

## 🧪 Testing

1. Run the opt-in remediation as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediate_SecureBootCertUpdate_OptIn.ps1
   ```

2. Check the value. It shows `MicrosoftUpdateManagedOptIn` with `0x1`:

   ```
   reg query "HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot" /v MicrosoftUpdateManagedOptIn
   ```

3. Run the CA 2023 detection the same way and read the output line:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Detect_SecureBootCertUpdate_UEFICA2023.ps1
   ```

4. To see the values the detection uses, run in an elevated PowerShell:

   ```
   Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing | Select-Object UEFICA2023Status, WindowsUEFICA2023Capable, UEFICA2023Error
   [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI -Name db).Bytes) -match 'Windows UEFI CA 2023'
   ```

## 📝 Logging

The scripts write no log file. Their output is shown in the Intune admin center in the device status of each remediation. For the CA 2023 detection the output includes `UEFICA2023Status`, `WindowsUEFICA2023Capable` and `UEFICA2023Error`, or the result of the db check.

| Exit code | Meaning |
|---|---|
| `0` | Opt-in detection: `MicrosoftUpdateManagedOptIn` is `1`. CA 2023 detection: update applied (registry or db) |
| `1` | Opt-in detection: key or value missing, value not `1`, or the detection failed. CA 2023 detection: certificate not found in the db, or the db could not be read |

The opt-in remediation script sets no exit code. If setting the value fails, it writes the error to the error output. The post-remediation detection shows whether the value is set.

## ⚠️ Good to know

- **Opt-in is not the update itself.** The remediation only sets the opt-in value. The certificate update is done by Windows, the CA 2023 detection shows when it is applied.
- **Firmware first.** Microsoft recommends OEM firmware updates first, especially on older models, and a pilot group with different OEMs, firmware versions and BitLocker-enabled devices.
- **Policy alternative.** The Policy CSP setting [SecureBoot/ConfigureMicrosoftUpdateManagedOptIn](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-secureboot#configuremicrosoftupdatemanagedoptin) (`0` = disabled, `1` = enabled) controls the opt-in to Microsoft managed servicing as a policy.
- **Devices without Secure Boot** cannot pass the db check. If the registry check in step 2 does not match, the CA 2023 detection reports them as not compliant.

## 🛠️ Troubleshooting

| Symptom | Check |
|---|---|
| CA 2023 detection reports "Unable to access Secure Boot UEFI DB" | Device boots in UEFI mode with Secure Boot (`Confirm-SecureBootUEFI`), detection runs as SYSTEM |
| CA 2023 detection stays not compliant | `UEFICA2023Status` and `UEFICA2023Error` under `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing`, System event log for event ID `1801` or `1795`, OEM firmware version |

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
