# 💳 SmartCardRemovalPolicyService

Locking the device when a user removes the smart card (or a YubiKey used as smart card) needs the Smart Card Removal Policy service (`SCPolicySvc`). The policy "Interactive logon: Smart card removal behavior" only works while this service is started. If it is stopped or does not start automatically, nothing happens when the card is removed.

This remediation pair makes sure the service starts automatically and is running. The remediation sets it to Automatic (Delayed Start) and starts it. Without the removal policy the service stops right after the start, so both scripts check the policy first.

## ✨ Features

- Checks the removal policy (`ScRemoveOption`) first and changes nothing if it is not configured
- Checks that `SCPolicySvc` exists, starts automatically and is running
- Accepts both Automatic and Automatic (Delayed Start) as compliant
- Sets the start type to Automatic (Delayed Start) in the registry (`Start` = `2`, `DelayedAutostart` = `1`)
- Starts the service if it is not running
- Reports a missing service instead of failing silently

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | Reads `ScRemoveOption` (`REG_SZ`) under `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon` and compares it as text. Missing or not `1`, `2` or `3`: not compliant, exit `1` |
| 2 | Detect | `Get-Service SCPolicySvc`. Service not found: not compliant, exit `1` |
| 3 | Detect | Reads `Start` and `DelayedAutostart` under `HKLM\SYSTEM\CurrentControlSet\Services\SCPolicySvc`. `Start` is not `2` (Automatic): not compliant, exit `1`. `DelayedAutostart` is only shown in the output |
| 4 | Detect | Service status is not `Running`: not compliant, exit `1`. Otherwise compliant, exit `0` |
| 5 | Remediate | `ScRemoveOption` missing or not `1`, `2` or `3`: changes nothing (the start type stays as it is), exit `1` |
| 6 | Remediate | Service not found: error, exit `1` |
| 7 | Remediate | Sets `Start` = `2` and `DelayedAutostart` = `1` (both `REG_DWORD`) |
| 8 | Remediate | Starts the service with `Start-Service` if it is not running. Any error: exit `1` |

| Registry key | Value | Type | Data |
|---|---|---|---|
| `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon` | `ScRemoveOption` | `REG_SZ` | Read only. `0` = no action, `1` = lock workstation, `2` = force logoff, `3` = disconnect if remote session |
| `HKLM\SYSTEM\CurrentControlSet\Services\SCPolicySvc` | `Start` | `REG_DWORD` | `2` = Automatic |
| `HKLM\SYSTEM\CurrentControlSet\Services\SCPolicySvc` | `DelayedAutostart` | `REG_DWORD` | `1` = Delayed Start |

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows Enterprise, Pro or Education, Microsoft Entra joined or Microsoft Entra hybrid joined, enrolled in Intune or co-managed |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | SYSTEM |
| License | Remediations require Windows Enterprise E3 or E5, Windows Education A3 or A5, or Windows VDA per user |
| Policy | "Interactive logon: Smart card removal behavior" set to `1`, `2` or `3` on the device (`ScRemoveOption`), configured separately (see Good to know). Without it the scripts report not compliant and change nothing |

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

The removal policy must be set on the test device (`ScRemoveOption` `1`, `2` or `3`), otherwise both scripts return exit `1` with the policy message and change nothing.

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
| `1` | Detection: removal policy not configured, service missing, `Start` not `2`, or service not running. Remediation: removal policy not configured (nothing changed), service missing, or setting the registry values or starting the service failed |

## ⚠️ Good to know

- **The service alone does not lock anything.** The lock on removal needs the policy "Interactive logon: Smart card removal behavior", for example Policy CSP [LocalPoliciesSecurityOptions/InteractiveLogon_SmartCardRemovalBehavior](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-localpoliciessecurityoptions#interactivelogon_smartcardremovalbehavior) with `1` = Lock Workstation. Configure it separately. For this setting to work, the Smart Card Removal Policy service must be started.
- **The service needs the policy.** Without `ScRemoveOption` `1`, `2` or `3`, `SCPolicySvc` stops by itself right after it starts, even when started by hand. That is why the scripts check the policy first: without it the detection reports not compliant and the remediation changes nothing and ends with exit `1`. Assign the remediation only to devices that also get the removal policy, or assign the policy first.
- **Service was Disabled before.** The remediation sets the new start type through the registry. It takes effect after the next restart. Until then, starting the service can fail, and the remediation reports an error until the device is restarted.
- **Delayed start.** After a restart the service starts a bit later than services with Automatic. The detection accepts both Automatic and Automatic (Delayed Start).

## 🛠️ Troubleshooting

| Symptom | Check |
|---|---|
| Detection: `Not compliant: smart card removal policy (ScRemoveOption) is not configured, SCPolicySvc stops without it` | The policy "Interactive logon: Smart card removal behavior" is not on the device. Check `ScRemoveOption` under `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`, it must be `1`, `2` or `3` |
| Remediation: `Not remediated: smart card removal policy (ScRemoveOption) is not configured. Assign the policy Interactive logon: Smart card removal behavior to this device.` | Same cause, the remediation changed nothing. Assign the policy (for example [LocalPoliciesSecurityOptions/InteractiveLogon_SmartCardRemovalBehavior](https://learn.microsoft.com/windows/client-management/mdm/policy-csp-localpoliciessecurityoptions#interactivelogon_smartcardremovalbehavior)) and wait for the next run |
| Remediation fails with an error when starting the service | The service was Disabled before, the new start type takes effect after the next restart (see Good to know) |

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
