<#
Script:      Detect_RebootReminder.ps1
Author:      Daniel Fraubaum
Blog:        https://headsinthecloud.blog
Version:     1.0
Date:        2026-11-18
Description: Intune Remediation detection script (run as SYSTEM, 64-bit).
             Checks the device uptime against $MaxUptimeDays.
             Exit 0 = compliant or reboot already scheduled for this boot session.
             Exit 1 = uptime limit exceeded, remediation shows the reboot popup and schedules the enforced reboot.
             Cleans up the transient scheduled tasks and registry state once the device has rebooted.
#>

# ==========================================================================
# Parameters
# ==========================================================================

# Must match the value in Remediate_RebootReminder.ps1
$MaxUptimeDays = 7

# If a scheduled reboot is overdue by more than this, detection fails again and remediation reboots right away
$OverdueGraceMinutes = 15

# Testing only: fake uptime in days (e.g. 10). Set to $null for production
$TestUptimeDays = $null

# Used for registry key, ProgramData folder and Task Scheduler folder
$OrgPrefix = "headsinthecloud.blog"
$RegPath = "HKLM:\SOFTWARE\$OrgPrefix\RebootReminder"
$TaskPath = "\$OrgPrefix\"
$PopupTaskName = "RebootReminder-Popup"
$RebootTaskName = "RebootReminder-EnforcedReboot"
$LogFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\RebootReminder.log"

# ==========================================================================
# Functions
# ==========================================================================

function Write-Log {
    param ([string]$Message)
    try {
        $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Add-Content -Path $LogFile -Value "$TimeStamp [Detect] $Message" -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        # Logging must never break detection
    }
}

function Clear-RebootReminderState {
    foreach ($TaskName in @($PopupTaskName, $RebootTaskName)) {
        if (Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
            Write-Log "Removed scheduled task $TaskPath$TaskName"
        }
    }
    if (Test-Path -Path $RegPath) {
        Remove-Item -Path $RegPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Removed registry state $RegPath"
    }
}

# ==========================================================================
# Logic
# ==========================================================================

try {
    # Step 1: Determine uptime
    $LastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
    $UptimeDays = [math]::Floor(((Get-Date) - $LastBoot).TotalDays)
    if ($null -ne $TestUptimeDays) {
        $UptimeDays = [int]$TestUptimeDays
        Write-Log "Testing value active, uptime overridden to $UptimeDays days"
    }

    # Step 2: Read existing schedule state
    $State = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
    $ScheduledInThisBoot = $false
    $Deadline = $null
    if ($State -and $State.ScheduledAtUtcTicks -and $State.DeadlineUtcTicks) {
        $ScheduledAt = ([datetime]::new([int64]$State.ScheduledAtUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
        $Deadline = ([datetime]::new([int64]$State.DeadlineUtcTicks, [DateTimeKind]::Utc)).ToLocalTime()
        $ScheduledInThisBoot = $ScheduledAt -gt $LastBoot
    }
    $RebootTaskExists = [bool](Get-ScheduledTask -TaskPath $TaskPath -TaskName $RebootTaskName -ErrorAction SilentlyContinue)

    # Step 3: Compliant, clean up leftovers from a previous cycle
    if ($UptimeDays -lt $MaxUptimeDays) {
        if ($State -or $RebootTaskExists) {
            Clear-RebootReminderState
        }
        Write-Log "Compliant, uptime $UptimeDays days (limit $MaxUptimeDays)"
        Write-Output "Compliant: uptime $UptimeDays days (limit $MaxUptimeDays)"
        exit 0
    }

    # Step 4: Reboot already scheduled in this boot session and not overdue
    if ($ScheduledInThisBoot -and $RebootTaskExists -and ((Get-Date) -lt $Deadline.AddMinutes($OverdueGraceMinutes))) {
        Write-Log "Reboot already scheduled for $($Deadline.ToString("yyyy-MM-dd HH:mm")), uptime $UptimeDays days"
        Write-Output "Pending: reboot scheduled for $($Deadline.ToString("yyyy-MM-dd HH:mm")), uptime $UptimeDays days"
        exit 0
    }

    # Step 5: Not compliant
    Write-Log "Not compliant, uptime $UptimeDays days (limit $MaxUptimeDays)"
    Write-Output "Not compliant: uptime $UptimeDays days (limit $MaxUptimeDays)"
    exit 1
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)"
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
