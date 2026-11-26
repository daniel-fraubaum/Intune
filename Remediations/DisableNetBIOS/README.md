# 🌐 DisableNetBIOS

NetBIOS over TCP/IP is a legacy name resolution and session protocol. Windows configures it per network adapter, so one adapter can have it turned off while a new docking station or Wi-Fi adapter still has it on.

This remediation pair turns off NetBIOS over TCP/IP on every active, physical network adapter with IP enabled. It uses the `SetTcpipNetbios` method of `Win32_NetworkAdapterConfiguration`, reads the adapter again to verify the result and checks all adapters on every run.

## ✨ Features

- Sets `TcpipNetbiosOptions` to `2` (disable NetBIOS) on all adapters in scope
- Scope: adapters that are up, have a connector present and are physical (hardware interface or not virtual), with IP enabled
- Matches `Get-NetAdapter` and `Win32_NetworkAdapterConfiguration` by interface index, not by MAC address
- Changes only adapters with another value, adapters that are already at `2` are left alone
- Accepts the `SetTcpipNetbios` return values `0` and `1` (`1` = done, restart required)
- Reads every changed adapter again and reports an error if the value is still wrong
- Lists the non-compliant adapters with their current value in the detection output
- Covers new adapters on the next run

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | `Get-NetAdapter`: keeps adapters with `Status` `Up`, `ConnectorPresent` and (`HardwareInterface` or not `Virtual`) |
| 2 | Detect | `Win32_NetworkAdapterConfiguration` with `IPEnabled = TRUE`, matched to these adapters by `InterfaceIndex`. No adapter left: compliant, exit `0` |
| 3 | Detect | Any adapter with `TcpipNetbiosOptions` other than `2`: not compliant, exit `1`. Otherwise exit `0` |
| 4 | Remediate | Same scope as steps 1 and 2. Adapters already at `2` are logged as `OK` and skipped |
| 5 | Remediate | `Invoke-CimMethod ... -MethodName SetTcpipNetbios` with `TcpipNetbiosOptions = 2`. A return value other than `0` or `1` counts as an error |
| 6 | Remediate | Reads the adapter configuration again by `Index` and checks that `TcpipNetbiosOptions` is `2` |
| 7 | Remediate | Exit `1` if at least one adapter failed, otherwise exit `0` |

Adapters without an IP-enabled configuration are not touched.

`TcpipNetbiosOptions` values ([Win32_NetworkAdapterConfiguration](https://learn.microsoft.com/windows/win32/cimwin32prov/win32-networkadapterconfiguration)):

| Value | Meaning |
|---|---|
| `0` | Enable NetBIOS via DHCP |
| `1` | Enable NetBIOS |
| `2` | Disable NetBIOS |

`SetTcpipNetbios` return values used by the remediation ([SetTcpipNetbios method](https://learn.microsoft.com/windows/win32/cimwin32prov/settcpipnetbios-method-in-class-win32-networkadapterconfiguration)):

| Return value | Meaning |
|---|---|
| `0` | Successful completion, no reboot required |
| `1` | Successful completion, reboot required |
| Any other | Error, the adapter counts as failed |

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows Enterprise, Pro or Education, Microsoft Entra joined or Microsoft Entra hybrid joined, enrolled in Intune or co-managed |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | SYSTEM |
| License | Remediations require Windows Enterprise E3 or E5, Windows Education A3 or A5, or Windows VDA per user |

## 🔧 Configuration

The Parameters block has one value. Leave it at `2` for this package.

| Variable | Default | Description |
|---|---|---|
| `$DesiredOption` | `2` | Target value for `TcpipNetbiosOptions`: `0` = from DHCP, `1` = enabled, `2` = disabled. Must be the same in both scripts |

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

| Setting | Value |
|---|---|
| Detection script file | `Detect_DisableNetBIOS.ps1` |
| Remediation script file | `Remediate_DisableNetBIOS.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups |
| Schedule | Daily |

## 🧪 Testing

1. Show the current state from an elevated PowerShell:

   ```
   Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE" | Select-Object InterfaceIndex, Description, TcpipNetbiosOptions
   ```

2. Run the detection as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt. It returns `Not compliant` with the adapter list if one adapter in scope is not at `2`:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Detect_DisableNetBIOS.ps1
   ```

3. Run the remediation the same way:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediate_DisableNetBIOS.ps1
   ```

4. Run the command from step 1 again. Every active, physical adapter shows `TcpipNetbiosOptions` `2`. The detection now returns `Compliant`.

## 📝 Logging

The scripts write no log file. Their output is shown in the Intune admin center in the device status of the remediation (pre-remediation detection output, remediation output, post-remediation detection output).

Remediation output per adapter:

| Prefix | Meaning |
|---|---|
| `OK:` | Already disabled, nothing changed |
| `Set:` | Disabled now, with the previous value |
| `Error:` | `SetTcpipNetbios` returned another value, or the value is still wrong after the change |

| Exit code | Meaning |
|---|---|
| `0` | Detection: NetBIOS disabled on all adapters in scope, or no adapter in scope. Remediation: all adapters in scope are at `2`, or nothing to do |
| `1` | Detection: at least one adapter in scope is not at `2`, or the detection failed. Remediation: at least one adapter failed, or the remediation failed |

## ⚠️ Good to know

- **NetBIOS name resolution stops working** on the adapters in scope. Legacy apps or old file shares that rely on NetBIOS names no longer resolve them. Test them in the pilot group.
- **New adapters** (docking station, USB adapter, new Wi-Fi card) are covered on the next run, as soon as they are up and have IP enabled.
- **Disconnected adapters** are not in scope. An adapter that is down at the time of the run is checked on the first run after it comes up.
- **Virtual adapters** without a hardware interface are out of scope on purpose.
- **Restart:** if `SetTcpipNetbios` returns `1`, Windows reports that a restart is required. The script accepts this and still verifies the value it reads back.

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
