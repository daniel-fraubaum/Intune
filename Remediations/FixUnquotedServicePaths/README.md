# 🔒 FixUnquotedServicePaths

A service whose `ImagePath` contains a space and is not in quotes is ambiguous. For `C:\Program Files\Vendor App\service.exe` Windows tries `C:\Program.exe` first, then `C:\Program Files\Vendor.exe`, and only then the real file ([CreateProcess](https://learn.microsoft.com/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw)). If a user can write to one of the folders on that path, they can place an executable there that the service starts with its own rights, often SYSTEM. That is a privilege escalation.

This remediation pair finds unquoted service paths in the registry and puts quotes around the executable part. Arguments and the value type stay as they are, and every change is logged with the old and the new value.

## ✨ Features

- Checks the `ImagePath` of every key under `HKLM\SYSTEM\CurrentControlSet\Services`
- Finds the executable part exactly: the first `.exe` followed by a space or the end of the value that points to an existing file
- Reports and fixes only paths whose executable exists and contains a space, so every finding can be fixed
- Quotes only the executable part, arguments stay unchanged: `C:\Program Files\Vendor App\service.exe -k` becomes `"C:\Program Files\Vendor App\service.exe" -k`
- Keeps the value type (`REG_SZ` or `REG_EXPAND_SZ`) and environment variables such as `%ProgramFiles%` unexpanded
- Logs the old and the new value of every changed service to a transcript in the IME log folder, so **Collect diagnostics** includes it
- Detection and remediation use the same rule, so the remediation fixes exactly what the detection reports

## ⚙️ How it works

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | Reads `ImagePath` of every service key without expanding environment variables. Skips empty values and values that start with a quote (after trimming spaces) |
| 2 | Detect | Searches the value for `.exe` followed by a space or the end (case-insensitive). The first match whose path (environment variables expanded) is an existing file is the executable part, the rest are the arguments |
| 3 | Detect | Skips the service if no existing executable was found or the executable part has no space |
| 4 | Detect | At least one finding: not compliant, exit `1` with the service names. Otherwise exit `0` |
| 5 | Remediate | Rotates the log if needed and starts a transcript |
| 6 | Remediate | Finds the same services with the same rule as the detection |
| 7 | Remediate | Writes `"<executable part>"<arguments>` back to `ImagePath` with the original value type and logs `old:` and `new:` |
| 8 | Remediate | Exit `1` if at least one service could not be fixed, otherwise exit `0` |

Examples:

| `ImagePath` | Result |
|---|---|
| `C:\Program Files\Vendor App\service.exe -k` | Fixed: `"C:\Program Files\Vendor App\service.exe" -k` |
| `C:\Program Files\Vendor App\service.exe` | Fixed: `"C:\Program Files\Vendor App\service.exe"` |
| `"C:\Program Files\Vendor App\service.exe" -k` | Already quoted, skipped |
| `C:\Windows\system32\svchost.exe -k netsvcs` | No space in the executable part, skipped |
| `C:\Program Files\Old App\removed.exe` (file does not exist) | Skipped, cannot be fixed safely |

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows Enterprise, Pro or Education, Microsoft Entra joined or Microsoft Entra hybrid joined, enrolled in Intune or co-managed |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | SYSTEM (write access to `HKLM\SYSTEM\CurrentControlSet\Services`) |
| License | Remediations require Windows Enterprise E3 or E5, Windows Education A3 or A5, or Windows VDA per user |

## 🔧 Configuration

Adjust the Parameters block at the top of the scripts before you upload them.

| Variable | Default | Description |
|---|---|---|
| `$ServicesPath` | `HKLM:\SYSTEM\CurrentControlSet\Services` | Registry key with the services. Must be the same in both scripts. Do not change it |
| `$LogFile` | `$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\FixUnquotedServicePaths.log` | Transcript of the remediation (remediation script only) |
| `$MaxLogSizeKB` | `1024` | Above this size the log is renamed to `.log.old` before the next run (remediation script only) |

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

| Setting | Value |
|---|---|
| Detection script file | `Detect_FixUnquotedServicePaths.ps1` |
| Remediation script file | `Remediate_FixUnquotedServicePaths.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups |
| Schedule | Daily |

## 🧪 Testing

1. Create a test service with an unquoted path from an elevated PowerShell. The service is never started:

   ```
   New-Item -ItemType Directory -Path "C:\Program Files\Test App" -Force
   Copy-Item -Path C:\Windows\System32\notepad.exe -Destination "C:\Program Files\Test App\test.exe"
   sc.exe create TestUnquoted binPath= "C:\Program Files\Test App\test.exe -k" start= demand
   ```

2. Run the detection as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt. It returns `Not compliant` and lists `TestUnquoted`:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Detect_FixUnquotedServicePaths.ps1
   ```

3. Run the remediation the same way:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediate_FixUnquotedServicePaths.ps1
   ```

4. Check the value. It is now `"C:\Program Files\Test App\test.exe" -k`:

   ```
   reg query "HKLM\SYSTEM\CurrentControlSet\Services\TestUnquoted" /v ImagePath
   ```

5. Check the log for the `Fixed:`, `old:` and `new:` lines, then remove the test service:

   ```
   sc.exe delete TestUnquoted
   Remove-Item -Path "C:\Program Files\Test App" -Recurse -Force
   ```

## 📝 Logging

| Log | Location |
|---|---|
| Remediation transcript | `%ProgramData%\Microsoft\IntuneManagementExtension\Logs\FixUnquotedServicePaths.log`, appended on every run. If it is larger than `$MaxLogSizeKB` (1024 KB) when the remediation starts, it is renamed to `FixUnquotedServicePaths.log.old` (an older `.log.old` is replaced) |
| Remote | Intune admin center > device > **Collect diagnostics**. The IME log folder is part of the collection |
| Detection and remediation output | Intune admin center, device status of the remediation. The detection lists the names of the affected services |

Every fixed service is logged like this:

```
Fixed: <ServiceName>
  old: C:\Program Files\Vendor App\service.exe -k
  new: "C:\Program Files\Vendor App\service.exe" -k
```

| Exit code | Meaning |
|---|---|
| `0` | Detection: no unquoted service paths. Remediation: all findings fixed, or nothing to fix |
| `1` | Detection: at least one unquoted service path, or the detection failed. Remediation: at least one service could not be fixed, or the remediation failed |

## ⚠️ Good to know

- **Only services.** Uninstall strings and other unquoted paths (scheduled tasks, Run keys) are not handled.
- **Only `.exe` paths.** The executable part must end in `.exe`. Services whose executable does not exist are ignored, so every finding can be fixed.
- **No service restart.** The scripts only change the registry value. They do not stop, start or restart any service.
- **Output limit.** Intune keeps at most 2,048 characters of script output. With many findings the list in the admin center can be cut, the transcript has every change.
- **Roll back.** The old value is in the log. Set it back in `HKLM\SYSTEM\CurrentControlSet\Services\<name>\ImagePath` with the same value type, for example `reg add "HKLM\SYSTEM\CurrentControlSet\Services\<name>" /v ImagePath /t REG_EXPAND_SZ /d "<old value>" /f`. Exclude the device from the remediation first, otherwise the next run quotes it again.
- **Installers can bring it back.** An update of the software can write the unquoted path again. The next run fixes it again and logs it.

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
