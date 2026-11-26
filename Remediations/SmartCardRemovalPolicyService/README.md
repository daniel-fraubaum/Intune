# 💳 SmartCardRemovalPolicyService

Locking the device when a user removes the smart card (or a YubiKey used as smart card) needs the Smart Card Removal Policy service (`SCPolicySvc`). The policy "Interactive logon: Smart card removal behavior" only works while this service is started. If it is stopped or does not start automatically, nothing happens when the card is removed.

This remediation pair makes sure the service starts automatically and is running. The remediation sets it to Automatic (Delayed Start) and starts it.

## ✨ Features

- Checks that `SCPolicySvc` exists, starts automatically and is running
- Accepts both Automatic and Automatic (Delayed Start) as compliant
- Sets the start type to Automatic (Delayed Start) in the registry (`Start` = `2`, `DelayedAutostart` = `1`)
- Starts the service if it is not running
- Reports a missing service instead of failing silently

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | `Get-Service SCPolicySvc`. Service not found: not compliant, exit `1` |
| 2 | Detect | Reads `Start` and `DelayedAutostart` under `HKLM\SYSTEM\CurrentControlSet\Services\SCPolicySvc`. `Start` is not `2` (Automatic): not compliant, exit `1`. `DelayedAutostart` is only shown in the output |
| 3 | Detect | Service status is not `Running`: not compliant, exit `1`. Otherwise compliant, exit `0` |
| 4 | Remediate | Service not found: error, exit `1` |
| 5 | Remediate | Sets `Start` = `2` and `DelayedAutostart` = `1` (both `REG_DWORD`) |
| 6 | Remediate | Starts the service with `Start-Service` if it is not running. Any error: exit `1` |

| Registry key | Value | Type | Data |
|---|---|---|---|
| `HKLM\SYSTEM\CurrentControlSet\Services\SCPolicySvc` | `Start` | `REG_DWORD` | `2` = Automatic |
| `HKLM\SYSTEM\CurrentControlSet\Services\SCPolicySvc` | `DelayedAutostart` | `REG_DWORD` | `1` = Delayed Start |

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows Enterprise, Pro or Education, Microsoft Entra joined or Microsoft Entra hybrid joined, enrolled in Intune or co-managed |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | SYSTEM |
| License | Remediations require Windows Enterprise E3 or E5, Windows Education A3 or A5, or Windows VDA per user |
| Policy | "Interactive logon: Smart card removal behavior", configured separately (see Good to know) |

## 🔧 Configuration

No configuration needed.

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

| Setting | Value |
|---|---|
| Detection script file | `Detect_SmartCardRemovalPolicyService.ps1` |
| Remediation script file | `Remediate_SmartCardRemovalPolicyService.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups |
| Schedule | Daily |

## 🧪 Testing

1. Run the remediation as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediate_SmartCardRemovalPolicyService.ps1
   ```

2. Check the service and the registry values in an elevated PowerShell. Expected: `Running`, `Start` `2`, `DelayedAutostart` `1`:

   ```
   Get-Service -Name SCPolicySvc
   Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Services\SCPolicySvc | Select-Object Start, DelayedAutostart
   ```

3. Run the detection the same way. It returns `Compliant`:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Detect_SmartCardRemovalPolicyService.ps1
   ```

4. With the removal policy set to Lock Workstation, sign in with the smart card or YubiKey and remove it. The device locks.

## 📝 Logging

The scripts write no log file. Their output is shown in the Intune admin center in the device status of the remediation. The detection output contains the current `Start` value or the service status.

| Exit code | Meaning |
|---|---|
| `0` | Detection: service starts automatically (with or without delayed start) and is running. Remediation: start type set and service running |
| `1` | Detection: service missing, `Start` not `2`, or service not running. Remediation: service missing, or setting the registry values or starting the service failed |

## ⚠️ Good to know

- **The service alone does not lock anything.** The lock on removal needs the policy "Interactive logon: Smart card removal behavior", for example Policy CSP [LocalPoliciesSecurityOptions/InteractiveLogon_SmartCardRemovalBehavior](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-localpoliciessecurityoptions#interactivelogon_smartcardremovalbehavior) with `1` = Lock Workstation. Configure it separately. For this setting to work, the Smart Card Removal Policy service must be started.
- **Service was Disabled before.** The remediation sets the new start type through the registry. It takes effect after the next restart. Until then, starting the service can fail, and the remediation reports an error until the device is restarted.
- **Delayed start.** After a restart the service starts a bit later than services with Automatic. The detection accepts both Automatic and Automatic (Delayed Start).

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
