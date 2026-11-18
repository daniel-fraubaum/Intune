
# Intune Remediation: Reboot Reminder with Enforced Reboot

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.1**  
Last update: **2026-11-18**

This folder contains an **Intune Remediation** pair that keeps Windows devices from running for weeks without a restart.  
When a device has been up longer than `$MaxUptimeDays`, the signed-in user gets a modern popup with a live countdown. When the countdown runs out, the device is restarted by a SYSTEM task, whether or not the user reacted to the popup.

> Important  
> This remediation **restarts devices**. Test on a pilot group first and tell your users before you roll it out.

---

## What this package does

- Shows a **WPF popup in the bottom right corner** of the screen for every signed-in user  
  - Light and dark mode aware (follows the Windows app theme)  
  - **Live countdown** with progress bar, based on wall clock time, so sleep or hibernate does not stretch it  
  - **Restart now** and **Remind me later** buttons, "later" hides the popup for `$SnoozeMinutes`  
  - In the last `$FinalPhaseMinutes` the popup turns red and can no longer be hidden
- **Enforces the reboot** after `$CountdownMinutes` (default 2 hours). Closing or killing the popup does not stop it  
- **Reboots right away** (after `$NoUserRebootDelaySeconds`) when nobody is signed in  
- **Disables Fast Startup**, because Fast Startup keeps `LastBootUpTime` alive across shutdowns. Without this, a user who "shuts down every evening" never resets the uptime  
- Runs as **SYSTEM** in **64-bit PowerShell** through Intune Remediations

---

## Files

- `Detection_RebootReminder.ps1`  
  Detection script. Returns exit code `0` if the uptime is below the limit or a reboot is already scheduled for this boot session, `1` if remediation is required.

- `Remediation_RebootReminder.ps1`  
  Remediation script. Schedules the enforced reboot, deploys the popup and starts it for all signed-in users.

---

## How it works

### Detection

1. Reads `LastBootUpTime` and calculates the uptime in days  
2. **Uptime below `$MaxUptimeDays`**: the device is compliant. If tasks or registry state from a previous cycle are still there (the device has rebooted since), they are **cleaned up**. Exit `0`  
3. **Reboot already scheduled in this boot session** and the deadline is not overdue by more than `$OverdueGraceMinutes`: nothing to do, exit `0`. This stops the daily run from restarting the countdown  
4. Otherwise exit `1`, remediation runs

### Remediation

1. If a schedule from this boot session is **overdue** (the enforced reboot did not happen, e.g. the task was deleted), the device reboots after `$NoUserRebootDelaySeconds` and the script ends  
2. Disables Fast Startup (`HiberbootEnabled = 0`), takes effect with the upcoming reboot  
3. Writes the schedule (start time, deadline) and all popup texts and colors to `HKLM:\SOFTWARE\<OrgPrefix>\RebootReminder`  
4. Writes the popup script to `C:\ProgramData\<OrgPrefix>\RebootReminder\RebootReminderPopup.ps1` with a locked down ACL (SYSTEM and Administrators full control, Users read and execute only)  
5. Registers **two scheduled tasks** under `\<OrgPrefix>\` in Task Scheduler

| Task | Runs as | Purpose |
| --- | --- | --- |
| `RebootReminder-EnforcedReboot` | SYSTEM | One-time trigger at the deadline. Runs as soon as possible if the deadline was missed (device asleep or off). Only reboots if the device has not booted since the schedule was created |
| `RebootReminder-Popup` | BUILTIN\Users (each signed-in user) | Shows the popup in every interactive session. Starts right away, again every 15 minutes during the countdown (in case the user killed it) and at logon. A mutex keeps it to one popup per session |

6. If **nobody is signed in** (no `explorer.exe`), the device reboots after `$NoUserRebootDelaySeconds` instead of waiting for the countdown

### Cleanup after the reboot

After the reboot the uptime is back to 0. The next detection run sees a compliant device and removes both scheduled tasks and the registry key. The popup script in `ProgramData` stays and is overwritten on the next cycle.

---

## Why this is not a plain remediation

The obvious approach would be to show the popup and wait for the countdown inside the remediation script itself. That does not work:

- Intune stops Remediation scripts after **about an hour**. A two hour countdown can't run inside the script
- The remediation runs as **SYSTEM** in session 0, so it can't show a window to the user anyway

That's why the remediation only **sets things up** and ends within seconds. The countdown lives in the popup (user context, started by a scheduled task) and the reboot itself is done by a separate **SYSTEM scheduled task**. Both are independent of the Intune script runtime and of each other.

---

## Parameters

All parameters are at the top of the scripts in the **Parameters** section.

> Important  
> `$MaxUptimeDays` and `$OrgPrefix` **must be the same in both scripts**. Otherwise detection and remediation look at different limits or different registry keys and tasks.

| Parameter | Script | Default | Description |
| --- | --- | --- | --- |
| `$MaxUptimeDays` | Both | `7` | Uptime in days that triggers the reminder. **Must match in both scripts** |
| `$OrgPrefix` | Both | `"headsinthecloud.blog"` | Used for the registry key, the ProgramData folder and the Task Scheduler folder. **Must match in both scripts** |
| `$TestUptimeDays` | Both | `$null` | Testing only: fakes the uptime in days. Set to `$null` for production |
| `$OverdueGraceMinutes` | Detection | `15` | If a scheduled reboot is overdue by more than this, detection fails again and remediation reboots right away |
| `$CountdownMinutes` | Remediation | `120` | Countdown until the enforced reboot |
| `$SnoozeMinutes` | Remediation | `30` | "Remind me later" hides the popup for this long |
| `$FinalPhaseMinutes` | Remediation | `15` | During the last X minutes the popup can no longer be hidden |
| `$RebootImmediatelyIfNoUser` | Remediation | `$true` | Reboot after `$NoUserRebootDelaySeconds` if nobody is signed in |
| `$NoUserRebootDelaySeconds` | Remediation | `300` | Delay for the reboot without a signed-in user, and for an overdue reboot |
| `$DisableFastStartup` | Remediation | `$true` | Disables Fast Startup so a shutdown resets the uptime |
| `$CompanyName` | Remediation | `"headsinthecloud.blog"` | Shown below the title in the popup |
| `$AccentColor` | Remediation | `"#0078D4"` | Icon, progress bar and "Restart now" button. Keep it dark enough for white button text |
| `$FinalAccentColor` | Remediation | `"#C42B1C"` | Accent color during the final phase |
| `$TitleText` | Remediation | `"Restart required"` | Popup title |
| `$MessageText` | Remediation | `"Your device has not been restarted for {0} days. ..."` | Main text, `{0}` = uptime in days |
| `$CountdownLabelText` | Remediation | `"Automatic restart in"` | Label next to the countdown |
| `$HintText` | Remediation | `"Your device will restart automatically at {0} at the latest."` | Hint below the progress bar, `{0}` = deadline time |
| `$ButtonNowText` | Remediation | `"Restart now"` | Primary button |
| `$ButtonLaterText` | Remediation | `"Remind me later"` | Secondary button |
| `$RestartingText` | Remediation | `"Your device is restarting now. Please save your work immediately."` | Shown when the restart starts |
| `$ShutdownComment` | Remediation | `"Scheduled maintenance restart by IT."` | Comment passed to `shutdown.exe`, visible in the event log |

> Note  
> The popup reads its texts from the registry, so keep them **ASCII only**. Windows PowerShell 5.1 reads scripts without a BOM as ANSI, and Intune Remediations run in Windows PowerShell 5.1.

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create**

2. **Basics**  
   - Name: `Reboot Reminder - Enforced reboot after 7 days uptime`  
   - Description: Shows a reboot popup with countdown and enforces the reboot

3. **Settings**  
   - Detection script file: `Detection_RebootReminder.ps1`  
   - Remediation script file: `Remediation_RebootReminder.ps1`  
   - Run this script using the logged-on credentials: **No** (runs as SYSTEM)  
   - Enforce script signature check: **No**  
   - Run script in 64-bit PowerShell: **Yes**

4. **Assignments**  
   - Assign to **device groups**, not user groups  
   - **Exclude multi-session AVD** session hosts. An enforced reboot would kick every user off the host, and the "nobody signed in" check does not fit a multi-session host. Use an exclude group or an assignment filter:
     ```
     (device.operatingSystemSKU -eq "ServerRdsh")
     ```
     set to **Exclude**

5. **Schedule**  
   - **Daily**

6. **Monitor**  
   - Review status in the Remediation dashboard  
   - The pre-remediation and post-remediation detection output shows the uptime and the scheduled deadline

---

## Testing

Test on a **VM or a test device**. The device **will restart**.

1. In `Remediation_RebootReminder.ps1` set:
   ```powershell
   $TestUptimeDays = 10
   $CountdownMinutes = 5
   ```
2. Sign in to the test device with a normal user account  
3. Run the remediation as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt:
   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediation_RebootReminder.ps1
   ```
4. The popup appears in the bottom right corner within a few seconds. Check the tasks under `\headsinthecloud.blog\` in Task Scheduler  
5. After 5 minutes the SYSTEM task reboots the device  
6. After the reboot, run the detection script the same way to verify the cleanup (tasks and registry key removed):
   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Detection_RebootReminder.ps1
   ```

> Note  
> With `$CountdownMinutes = 5` the countdown is shorter than `$FinalPhaseMinutes` (15), so the popup starts directly in the red final phase without "Remind me later". To test snoozing, also set `$FinalPhaseMinutes = 2`.

> Important  
> Set `$TestUptimeDays` back to `$null` and `$CountdownMinutes` back to `120` before uploading. If `$TestUptimeDays` stays set in the detection script, the device never becomes compliant and reboots every day.

---

## Logs

| Log | Location | Content |
| --- | --- | --- |
| Detection and remediation | `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\RebootReminder.log` | Uptime, deadline, registered tasks, cleanup, errors. Lines are tagged `[Detect]` or `[Remediate]`. Collected by **Collect diagnostics** in Intune |
| Popup | `%TEMP%\RebootReminderPopup.log` of the signed-in user | Popup start, snooze, final phase, "Restart now" clicks |
| Reboot | Event Viewer → Windows Logs → System, event ID **1074** | Who triggered the restart, with the `$ShutdownComment` |

State and tasks for troubleshooting:

- Registry: `HKLM:\SOFTWARE\headsinthecloud.blog\RebootReminder`  
- Task Scheduler: `\headsinthecloud.blog\RebootReminder-EnforcedReboot` and `\headsinthecloud.blog\RebootReminder-Popup`  
- Popup script: `C:\ProgramData\headsinthecloud.blog\RebootReminder\RebootReminderPopup.ps1`

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
