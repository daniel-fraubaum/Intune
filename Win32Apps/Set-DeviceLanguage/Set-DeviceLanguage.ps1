<#
    Script:      Set-DeviceLanguage.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.7
    Date:        2026-11-26
    Description: Installs a Windows display language and applies display language, preferred
                 language list, regional format, country/region and system locale (follows
                 -Culture). Existing languages and keyboards are kept and the previous default
                 keyboard stays the default.
                 Settings are copied to the Welcome screen and new user profiles. If a user is
                 signed in, the settings are also applied to that user via a one-time scheduled
                 task in user context.
                 Built as Intune Win32 app in SYSTEM context for Autopilot ESP (required, with
                 -InitialSetup) and Company Portal (available).
                 If a user is signed in, a restart reminder popup (LanguageRestartPopup.ps1, part
                 of the package) is shown bottom right until the device is restarted, and the
                 script returns 0. Optionally the restart is enforced after a deadline. Without a
                 signed-in user, with -InitialSetup or with -NoRestartReminder the script returns
                 3010 and Intune handles the restart.
                 Before Install-Language the script waits until no other servicing operation
                 (for example a cumulative update) is running. If Install-Language fails, it is
                 tried once more after 5 minutes. If servicing stays busy, a reboot is pending or
                 both attempts fail, the script returns exit code 1618 so that Intune retries the
                 installation instead of failing it. With -InitialSetup a pending reboot does not
                 stop the installation, the ESP handles reboots.
                 A language only counts as installed if its UI language pack is present
                 (LanguagePacks LpCab or Lxp). Language features left behind by a failed
                 installation do not count, and Install-Language is checked the same way.
#>

# ==========================================================================================
# Parameters
# ==========================================================================================
param (
    # Display language to install and apply (BCP-47 tag, e.g. "de-DE", "en-US")
    [Parameter(Mandatory = $true)]
    [string]$Language,

    # Regional format for date, time, numbers and currency (e.g. "de-AT"). Empty = same as $Language
    [string]$Culture = "",

    # Country or region (GeoId, e.g. 14 = Austria, 94 = Germany). 0 = leave unchanged
    # https://learn.microsoft.com/windows/win32/intl/table-of-geographical-locations
    [int]$GeoId = 0,

    # Use for the Autopilot app: additionally writes the initial language marker
    [switch]$InitialSetup,

    # Restart reminder: enforce the restart after X minutes. 0 = reminder only, never restart automatically
    [int]$RestartDeadlineMinutes = 0,

    # Restart reminder: "Remind me later" hides the popup for X minutes
    [int]$ReminderIntervalMinutes = 30,

    # Skip the restart reminder and return 3010, Intune handles the restart
    [switch]$NoRestartReminder
)

# Registry key for the Intune detection markers
$MarkerKeyPath = "HKLM:\SOFTWARE\CompanyName\DeviceLanguage"

# Marker value for the Company Portal apps (last selected language)
$MarkerValueName = "Language"

# Marker value for the Autopilot app (written only with -InitialSetup, never changed afterwards)
$InitialMarkerValueName = "InitialLanguage"

# Working folder for the temporary user script and the restart reminder popup
# Program Files, not ProgramData: standard users can create folders in ProgramData and would own them
$WorkingFolder = "$env:ProgramFiles\CompanyName\DeviceLanguage"

# Log file (IME log folder, collected with "Collect diagnostics")
$LogFile = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\Set-DeviceLanguage.log"

# Maximum wait time for the user part in seconds
$UserTaskTimeoutSeconds = 300

# Exit code that tells Intune to retry the installation (1618 is mapped to "Retry" by default)
$RetryExitCode = 1618

# Maximum wait time in minutes for other servicing operations to finish before Install-Language
$ServicingWaitMinutes = 10

# Check interval in seconds while waiting for servicing
$ServicingCheckIntervalSeconds = 30

# Processes that indicate an active servicing operation (component store or Windows Update)
$ServicingProcessNames = @("TiWorker")

# Wait time in minutes before the second Install-Language attempt
$InstallRetryWaitMinutes = 5

# Restart reminder: popup script shipped next to this script in the .intunewin package
$PopupFileName = "LanguageRestartPopup.ps1"

# Restart reminder: registry key for schedule, texts and colors (read by the popup)
$ReminderRegPath = "$MarkerKeyPath\RestartReminder"

# Restart reminder: Task Scheduler folder and task names
$TaskPath = "\DeviceLanguage\"
$PopupTaskName = "LanguageRestart-Popup"
$RebootTaskName = "LanguageRestart-EnforcedRestart"
$CleanupTaskName = "LanguageRestart-Cleanup"

# Restart reminder: during the last X minutes before an enforced restart the popup can no longer be hidden
$FinalPhaseMinutes = 15

# Restart reminder: branding and texts, ASCII only ({0} = language name in MessageText, {0} = deadline time in HintText)
$CompanyName = "IT Department"
$AccentColor = "#0078D4"
$FinalAccentColor = "#C42B1C"
$TitleText = "Restart required"
$MessageText = "{0} is ready. Restart your device to switch Windows to the new display language."
$CountdownLabelText = "Automatic restart in"
$HintText = "Your device will restart automatically at {0} at the latest."
$ButtonNowText = "Restart now"
$ButtonLaterText = "Remind me later"
$RestartingText = "Your device is restarting now. Please save your work."
$ShutdownComment = "Restart to apply the new Windows display language."

# ==========================================================================================
# Functions
# ==========================================================================================

# True if the folder is a real folder (no link) owned by SYSTEM, Administrators or TrustedInstaller
function Test-TrustedFolder {
    param ([string]$Path)
    $TrustedOwners = @("S-1-5-18", "S-1-5-32-544", "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464")
    $Item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { return $false }
    $Owner = (Get-Acl -LiteralPath $Path).GetOwner([System.Security.Principal.SecurityIdentifier]).Value
    return ($TrustedOwners -contains $Owner)
}

# ==========================================================================================
# Logic
# ==========================================================================================

# Step 1: Start logging
Start-Transcript -Path $LogFile -Append | Out-Null
Write-Output "Starting Set-DeviceLanguage. Language: $Language, Culture: $Culture, GeoId: $GeoId, RestartDeadlineMinutes: $RestartDeadlineMinutes, ReminderIntervalMinutes: $ReminderIntervalMinutes, NoRestartReminder: $NoRestartReminder"

if ([string]::IsNullOrWhiteSpace($Culture)) {
    $Culture = $Language
}

# Step 2: Check prerequisites
$Problems = @()

if (-not [System.Environment]::Is64BitProcess) {
    $Problems += "Script must run in 64-bit PowerShell. Use %windir%\SysNative\WindowsPowerShell\v1.0\powershell.exe as install command."
}

$CurrentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $CurrentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $Problems += "Script must run as SYSTEM or administrator. Set install behavior of the Win32 app to System."
}

$OsBuild = [System.Environment]::OSVersion.Version.Build
if ($OsBuild -lt 22621) {
    $Problems += "Windows 11 22H2 (build 22621) or later is required for Install-Language. Current build: $OsBuild"
}

if (-not (Get-Module -ListAvailable -Name "LanguagePackManagement")) {
    $Problems += "PowerShell module LanguagePackManagement is not available on this device."
}

if ($RestartDeadlineMinutes -lt 0) {
    $Problems += "RestartDeadlineMinutes must be 0 (reminder only) or a positive number of minutes. Current value: $RestartDeadlineMinutes"
}

if ($ReminderIntervalMinutes -lt 5) {
    $Problems += "ReminderIntervalMinutes must be at least 5. Current value: $ReminderIntervalMinutes"
}

$PopupSourcePath = Join-Path -Path $PSScriptRoot -ChildPath $PopupFileName
if (-not $NoRestartReminder -and -not $InitialSetup -and -not (Test-Path -Path $PopupSourcePath)) {
    $Problems += "$PopupFileName is missing next to Set-DeviceLanguage.ps1. Add it to the .intunewin source folder or use -NoRestartReminder."
}

foreach ($Tag in @($Language, $Culture)) {
    try {
        $TagInfo = [System.Globalization.CultureInfo]::GetCultureInfo($Tag)
        if ($TagInfo.IsNeutralCulture) {
            $Problems += "Language or culture tag $Tag has no region. Use a tag with region, for example de-AT or en-US."
        }
    }
    catch {
        $Problems += "Invalid language or culture tag: $Tag"
    }
}

if ($Problems.Count -gt 0) {
    foreach ($Problem in $Problems) {
        Write-Error $Problem
    }
    Stop-Transcript | Out-Null
    exit 1
}

# Step 3: Install language pack and language features if the UI language pack is missing
# A failed Install-Language can leave only the language features behind (LanguagePacks = None).
# The language then shows up in Get-InstalledLanguage, but Windows cannot switch to it.
function Get-LanguagePackState {
    param ([string]$Tag)
    $Installed = Get-InstalledLanguage -Language $Tag -ErrorAction SilentlyContinue
    if (-not $Installed) {
        return "NotInstalled"
    }
    return [string]$Installed.LanguagePacks
}

function Test-LanguagePackInstalled {
    param ([string]$Tag)
    return (Get-LanguagePackState -Tag $Tag) -match "LpCab|Lxp"
}

$LanguagePackState = Get-LanguagePackState -Tag $Language
if ($LanguagePackState -match "LpCab|Lxp") {
    Write-Output "Language $Language is already installed (LanguagePacks: $LanguagePackState). Skipping installation."
}
else {
    Write-Output "Language pack for $Language is missing (LanguagePacks: $LanguagePackState). Installation required."

    # Step 3.1: Stop if a reboot from a previous servicing operation is pending (not with -InitialSetup, the ESP handles reboots)
    $PendingRebootKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    $PendingReboot = $PendingRebootKeys | Where-Object { Test-Path -Path $_ }
    if ($PendingReboot -and $InitialSetup) {
        Write-Output "Reboot pending ($($PendingReboot -join ", ")). Initial setup: installing anyway, the ESP handles reboots."
    }
    elseif ($PendingReboot) {
        Write-Output "Reboot pending ($($PendingReboot -join ", ")). Language installation postponed, returning $RetryExitCode for Intune retry."
        Stop-Transcript | Out-Null
        exit $RetryExitCode
    }

    # Step 3.2: Wait until no other servicing operation (for example a cumulative update) is running
    $ServicingStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $ServicingBusy = Get-Process -Name $ServicingProcessNames -ErrorAction SilentlyContinue
    while ($ServicingBusy -and $ServicingStopwatch.Elapsed.TotalMinutes -lt $ServicingWaitMinutes) {
        Write-Output "Servicing operation in progress ($(($ServicingBusy.Name | Sort-Object -Unique) -join ", ")). Waiting $ServicingCheckIntervalSeconds seconds."
        Start-Sleep -Seconds $ServicingCheckIntervalSeconds
        $ServicingBusy = Get-Process -Name $ServicingProcessNames -ErrorAction SilentlyContinue
    }
    if ($ServicingBusy) {
        Write-Output "Servicing still busy after $ServicingWaitMinutes minutes. Language installation postponed, returning $RetryExitCode for Intune retry."
        Stop-Transcript | Out-Null
        exit $RetryExitCode
    }

    # Step 3.3: Install language, second attempt after $InstallRetryWaitMinutes minutes, then return retry to Intune (prerequisites are already checked)
    $MaxAttempts = 2
    for ($Attempt = 1; $Attempt -le $MaxAttempts; $Attempt++) {
        try {
            Write-Output "Installing language $Language (attempt $Attempt of $MaxAttempts). This can take up to 20 minutes."
            Install-Language -Language $Language -ErrorAction Stop | Out-Null
            if (-not (Test-LanguagePackInstalled -Tag $Language)) {
                throw "Install-Language finished, but the language pack for $Language is still missing (LanguagePacks: $(Get-LanguagePackState -Tag $Language))."
            }
            Write-Output "Language $Language installed successfully (LanguagePacks: $(Get-LanguagePackState -Tag $Language))."
            break
        }
        catch {
            $ErrorMessage = $_.Exception.Message
            $ErrorCode = ""
            if ($ErrorMessage -match "ErrorCode:\s*(-?\d+)") {
                # [int64] and the lower 32 bits, so positive and negative HRESULTs both format without an overflow
                $ErrorCode = " (0x{0:X8})" -f ([int64]$Matches[1] -band 0xFFFFFFFFL)
            }
            $RebootAfterFailure = $PendingRebootKeys | Where-Object { Test-Path -Path $_ }
            if ($RebootAfterFailure) {
                $ErrorMessage += " Reboot is pending now, a parallel update was probably installed."
            }
            if ($Attempt -lt $MaxAttempts) {
                Write-Warning "Attempt $Attempt of $MaxAttempts to install language $Language failed$ErrorCode`: $ErrorMessage Trying again in $InstallRetryWaitMinutes minutes."
                Start-Sleep -Seconds ($InstallRetryWaitMinutes * 60)
            }
            else {
                Write-Error "Attempt $Attempt of $MaxAttempts to install language $Language failed$ErrorCode`: $ErrorMessage Returning $RetryExitCode for Intune retry."
                Stop-Transcript | Out-Null
                exit $RetryExitCode
            }
        }
    }
}

# Step 4: Apply settings to the SYSTEM account (source for Welcome screen and new users)
try {
    Set-WinUILanguageOverride -Language $Language -ErrorAction Stop

    # Put the new language first, keep existing languages and keyboards, and keep the previous default keyboard
    # (the SYSTEM settings are copied to the Welcome screen in step 5, so this is the keyboard at sign-in)
    $CurrentList = Get-WinUserLanguageList
    $PreviousDefaultInput = [string](Get-WinDefaultInputMethodOverride)
    if ([string]::IsNullOrWhiteSpace($PreviousDefaultInput) -and $CurrentList.Count -gt 0 -and $CurrentList[0].InputMethodTips.Count -gt 0) {
        $PreviousDefaultInput = $CurrentList[0].InputMethodTips[0]
    }
    $NewList = New-WinUserLanguageList -Language $Language
    $Existing = @($CurrentList | Where-Object { $_.LanguageTag -eq $NewList[0].LanguageTag })
    if ($Existing.Count -gt 0) {
        $NewList.Clear()
        $NewList.Add($Existing[0])
    }
    foreach ($Item in $CurrentList) {
        if ($Item.LanguageTag -ne $NewList[0].LanguageTag) {
            $NewList.Add($Item)
        }
    }
    Set-WinUserLanguageList -LanguageList $NewList -Force -ErrorAction Stop
    if (-not [string]::IsNullOrWhiteSpace($PreviousDefaultInput)) {
        Set-WinDefaultInputMethodOverride -InputTip $PreviousDefaultInput -ErrorAction Stop
        Write-Output "Default keyboard kept: $PreviousDefaultInput"
    }

    Set-Culture -CultureInfo $Culture -ErrorAction Stop
    if ($GeoId -gt 0) {
        Set-WinHomeLocation -GeoId $GeoId -ErrorAction Stop
    }
    # The system locale (language for non-Unicode programs) follows the regional format, not the display language
    Set-WinSystemLocale -SystemLocale $Culture -ErrorAction Stop
    Write-Output "System settings applied (display language, language list, default keyboard, regional format, region, system locale $Culture)."
}
catch {
    Write-Error "Applying system settings failed: $($_.Exception.Message)"
    Stop-Transcript | Out-Null
    exit 1
}

# Step 5: Copy settings to Welcome screen, system accounts and new user profiles
try {
    Copy-UserInternationalSettingsToSystem -WelcomeScreen $true -NewUser $true -ErrorAction Stop
    Write-Output "Settings copied to Welcome screen and new user profiles."
}
catch {
    Write-Error "Copying settings to system failed: $($_.Exception.Message)"
    Stop-Transcript | Out-Null
    exit 1
}

# Step 6: Apply settings to signed-in users (skipped during Autopilot ESP device phase)
$SignedInUsers = Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" |
    ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName GetOwner } |
    Where-Object { $_.ReturnValue -eq 0 } |
    ForEach-Object { "$($_.Domain)\$($_.User)" } |
    Sort-Object -Unique

# The temporary user script runs as the signed-in user, so it must not be written into a folder a user controls
$WorkingFolderTrusted = $true
if ($SignedInUsers) {
    New-Item -Path $WorkingFolder -ItemType Directory -Force | Out-Null
    $WorkingFolderTrusted = Test-TrustedFolder -Path $WorkingFolder
}

if (-not $SignedInUsers) {
    Write-Output "No signed-in user found. User part skipped, new profiles get the settings from step 5."
}
elseif (-not $WorkingFolderTrusted) {
    Write-Error "$WorkingFolder is a link or not owned by SYSTEM or Administrators. User part skipped, system settings are applied anyway."
}
else {
    # Step 6.1: Write the temporary user script
    New-Item -Path $WorkingFolder -ItemType Directory -Force | Out-Null
    $UserScriptPath = Join-Path -Path $WorkingFolder -ChildPath "Set-UserLanguage.ps1"

    $UserScript = @'
param (
    [string]$Language,
    [string]$Culture,
    [int]$GeoId
)
try {
    # Put the new language first, keep existing languages and keyboards, and keep the previous default keyboard
    $CurrentList = Get-WinUserLanguageList
    $PreviousDefaultInput = [string](Get-WinDefaultInputMethodOverride)
    if ([string]::IsNullOrWhiteSpace($PreviousDefaultInput) -and $CurrentList.Count -gt 0 -and $CurrentList[0].InputMethodTips.Count -gt 0) {
        $PreviousDefaultInput = $CurrentList[0].InputMethodTips[0]
    }
    $NewList = New-WinUserLanguageList -Language $Language
    $Existing = @($CurrentList | Where-Object { $_.LanguageTag -eq $NewList[0].LanguageTag })
    if ($Existing.Count -gt 0) {
        $NewList.Clear()
        $NewList.Add($Existing[0])
    }
    foreach ($Item in $CurrentList) {
        if ($Item.LanguageTag -ne $NewList[0].LanguageTag) {
            $NewList.Add($Item)
        }
    }
    Set-WinUserLanguageList -LanguageList $NewList -Force -ErrorAction Stop
    if (-not [string]::IsNullOrWhiteSpace($PreviousDefaultInput)) {
        Set-WinDefaultInputMethodOverride -InputTip $PreviousDefaultInput -ErrorAction Stop
    }
    Set-WinUILanguageOverride -Language $Language -ErrorAction Stop
    Set-Culture -CultureInfo $Culture -ErrorAction Stop
    if ($GeoId -gt 0) {
        Set-WinHomeLocation -GeoId $GeoId -ErrorAction Stop
    }
    exit 0
}
catch {
    exit 1
}
'@
    Set-Content -Path $UserScriptPath -Value $UserScript -Encoding UTF8 -Force

    # Step 6.2: Run the user script once per signed-in user via scheduled task
    $PowerShellPath = "$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe"
    $TaskArguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$UserScriptPath`" -Language `"$Language`" -Culture `"$Culture`" -GeoId $GeoId"

    foreach ($UserName in $SignedInUsers) {
        $TaskName = "Set-UserLanguage-" + ($UserName -replace "[\\/:*?`"<>|]", "_")
        Write-Output "Applying user settings for $UserName."

        try {
            $TaskAction = New-ScheduledTaskAction -Execute $PowerShellPath -Argument $TaskArguments
            $TaskPrincipal = New-ScheduledTaskPrincipal -UserId $UserName -LogonType Interactive -RunLevel Limited
            $TaskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
            Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Principal $TaskPrincipal -Settings $TaskSettings -Force -ErrorAction Stop | Out-Null
            Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop

            # Step 6.3: Wait for the task to finish
            $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            do {
                Start-Sleep -Seconds 2
                $TaskState = (Get-ScheduledTask -TaskName $TaskName).State
            } while ($TaskState -eq "Running" -and $Stopwatch.Elapsed.TotalSeconds -lt $UserTaskTimeoutSeconds)

            $TaskResult = (Get-ScheduledTaskInfo -TaskName $TaskName).LastTaskResult
            if ($TaskState -eq "Running") {
                Write-Error "User part for $UserName did not finish within $UserTaskTimeoutSeconds seconds. System settings are applied anyway."
            }
            elseif ($TaskResult -eq 0) {
                Write-Output "User settings for $UserName applied successfully."
            }
            else {
                Write-Error "User part for $UserName failed with result $TaskResult. System settings are applied anyway."
            }
        }
        catch {
            Write-Error "User part for $UserName failed: $($_.Exception.Message). System settings are applied anyway."
        }
        finally {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

    # Step 6.4: Clean up the temporary user script
    Remove-Item -Path $UserScriptPath -Force -ErrorAction SilentlyContinue
}

# Step 7: Write detection marker
try {
    # Create the key only if missing, New-Item -Force would replace an existing key with an empty one
    if (-not (Test-Path -Path $MarkerKeyPath)) {
        New-Item -Path $MarkerKeyPath -Force -ErrorAction Stop | Out-Null
    }
    Set-ItemProperty -Path $MarkerKeyPath -Name $MarkerValueName -Value $Language -ErrorAction Stop
    Set-ItemProperty -Path $MarkerKeyPath -Name "Culture" -Value $Culture -ErrorAction Stop
    Set-ItemProperty -Path $MarkerKeyPath -Name "GeoId" -Value $GeoId -ErrorAction Stop
    Set-ItemProperty -Path $MarkerKeyPath -Name "LastChanged" -Value (Get-Date -Format "s") -ErrorAction Stop
    Write-Output "Detection marker written to $MarkerKeyPath ($MarkerValueName = $Language)."

    if ($InitialSetup) {
        Set-ItemProperty -Path $MarkerKeyPath -Name $InitialMarkerValueName -Value $Language -ErrorAction Stop
        Write-Output "Initial setup marker written to $MarkerKeyPath ($InitialMarkerValueName = $Language)."
    }
}
catch {
    Write-Error "Writing detection marker failed: $($_.Exception.Message)"
    Stop-Transcript | Out-Null
    exit 1
}

# Step 8: Restart reminder for signed-in users (Company Portal), Intune handles the restart otherwise
if ($NoRestartReminder) {
    Write-Output "Restart reminder disabled by -NoRestartReminder."
}
elseif ($InitialSetup) {
    Write-Output "Initial setup: no restart reminder, the restart is handled by Intune and the ESP."
}
elseif (-not $SignedInUsers) {
    Write-Output "No signed-in user: no restart reminder, the restart is handled by Intune."
}
else {
    try {
        # Step 8.1: Remove tasks and running popups from a previous language change
        foreach ($TaskName in @($PopupTaskName, $RebootTaskName, $CleanupTaskName)) {
            Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like "*$PopupFileName*" } |
            ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate | Out-Null }

        # Step 8.2: Write schedule, texts and colors for the popup (HKLM, readable by users)
        $Now = Get-Date
        $DeadlineTicks = [int64]0
        if ($RestartDeadlineMinutes -gt 0) {
            $Deadline = $Now.AddMinutes($RestartDeadlineMinutes)
            $DeadlineTicks = $Deadline.ToUniversalTime().Ticks
        }
        if (Test-Path -Path $ReminderRegPath) {
            Remove-Item -Path $ReminderRegPath -Recurse -Force -ErrorAction Stop
        }
        New-Item -Path $ReminderRegPath -Force -ErrorAction Stop | Out-Null
        $ReminderValues = [ordered]@{
            ScheduledAtUtcTicks     = @($Now.ToUniversalTime().Ticks, "QWord")
            DeadlineUtcTicks        = @($DeadlineTicks, "QWord")
            ReminderIntervalMinutes = @($ReminderIntervalMinutes, "DWord")
            FinalPhaseMinutes       = @($FinalPhaseMinutes, "DWord")
            LanguageName            = @([System.Globalization.CultureInfo]::GetCultureInfo($Language).EnglishName, "String")
            CompanyName             = @($CompanyName, "String")
            AccentColor             = @($AccentColor, "String")
            FinalAccentColor        = @($FinalAccentColor, "String")
            TitleText               = @($TitleText, "String")
            MessageText             = @($MessageText, "String")
            CountdownLabelText      = @($CountdownLabelText, "String")
            HintText                = @($HintText, "String")
            ButtonNowText           = @($ButtonNowText, "String")
            ButtonLaterText         = @($ButtonLaterText, "String")
            RestartingText          = @($RestartingText, "String")
            ShutdownComment         = @($ShutdownComment, "String")
        }
        foreach ($Entry in $ReminderValues.GetEnumerator()) {
            New-ItemProperty -Path $ReminderRegPath -Name $Entry.Key -Value $Entry.Value[0] -PropertyType $Entry.Value[1] -Force -ErrorAction Stop | Out-Null
        }

        # Step 8.3: Copy the popup to Program Files with a locked down ACL (users read and execute only)
        New-Item -Path $WorkingFolder -ItemType Directory -Force | Out-Null
        if (-not (Test-TrustedFolder -Path $WorkingFolder)) {
            throw "$WorkingFolder is a link or not owned by SYSTEM or Administrators"
        }
        $Acl = New-Object System.Security.AccessControl.DirectorySecurity
        $Acl.SetAccessRuleProtection($true, $false)
        $Inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
        $Propagation = [System.Security.AccessControl.PropagationFlags]::None
        foreach ($AclEntry in @(@("S-1-5-18", "FullControl"), @("S-1-5-32-544", "FullControl"), @("S-1-5-32-545", "ReadAndExecute"))) {
            $Sid = New-Object System.Security.Principal.SecurityIdentifier($AclEntry[0])
            $Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($Sid, $AclEntry[1], $Inheritance, $Propagation, "Allow")
            $Acl.AddAccessRule($Rule)
        }
        Set-Acl -Path $WorkingFolder -AclObject $Acl -ErrorAction Stop
        $PopupPath = Join-Path -Path $WorkingFolder -ChildPath $PopupFileName
        Copy-Item -Path $PopupSourcePath -Destination $PopupPath -Force -ErrorAction Stop

        # Step 8.4: Cleanup task, removes tasks, registry state and popup at the next startup
        $SystemPowerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $SystemPrincipal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $CleanupScript = "foreach (`$Name in @('$PopupTaskName', '$RebootTaskName', '$CleanupTaskName')) { Unregister-ScheduledTask -TaskPath '$TaskPath' -TaskName `$Name -Confirm:`$false -ErrorAction SilentlyContinue }; " +
                         "Remove-Item -Path '$ReminderRegPath' -Recurse -Force -ErrorAction SilentlyContinue; " +
                         "Remove-Item -Path '$PopupPath' -Force -ErrorAction SilentlyContinue"
        $EncodedCleanup = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($CleanupScript))
        $CleanupAction = New-ScheduledTaskAction -Execute $SystemPowerShell -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $EncodedCleanup"
        $CleanupSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
        Register-ScheduledTask -TaskPath $TaskPath -TaskName $CleanupTaskName -Action $CleanupAction -Trigger (New-ScheduledTaskTrigger -AtStartup) -Principal $SystemPrincipal -Settings $CleanupSettings -Description "Removes the language restart reminder after the restart (Set-DeviceLanguage)" -ErrorAction Stop | Out-Null
        Write-Output "Cleanup task registered, runs at the next startup."

        # Step 8.5: Optional enforced restart (only if the device has not restarted since the language change)
        if ($RestartDeadlineMinutes -gt 0) {
            $ScheduledAtTicks = $Now.ToUniversalTime().Ticks
            $GuardScript = "if ((Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime -lt ([datetime]::new($ScheduledAtTicks, [DateTimeKind]::Utc)).ToLocalTime()) { & `"$env:SystemRoot\System32\shutdown.exe`" /r /f /t 60 /d p:0:0 /c `"$ShutdownComment`" }"
            $EncodedGuard = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($GuardScript))
            $RebootAction = New-ScheduledTaskAction -Execute $SystemPowerShell -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand $EncodedGuard"
            $RebootSettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
            Register-ScheduledTask -TaskPath $TaskPath -TaskName $RebootTaskName -Action $RebootAction -Trigger (New-ScheduledTaskTrigger -Once -At $Deadline) -Principal $SystemPrincipal -Settings $RebootSettings -Description "Enforced restart after a display language change (Set-DeviceLanguage)" -ErrorAction Stop | Out-Null
            Write-Output "Enforced restart task registered for $Deadline."
        }

        # Step 8.6: Popup task for all signed-in users (now, again every interval as safety net, and at logon)
        $PopupArguments = "--headless `"$SystemPowerShell`" -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PopupPath`" -RegPath `"$ReminderRegPath`""
        $PopupAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\conhost.exe" -Argument $PopupArguments
        $PopupTriggers = @(
            (New-ScheduledTaskTrigger -AtLogOn),
            (New-ScheduledTaskTrigger -Once -At $Now.AddSeconds(5) -RepetitionInterval (New-TimeSpan -Minutes $ReminderIntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 30))
        )
        $PopupPrincipal = New-ScheduledTaskPrincipal -GroupId "S-1-5-32-545" -RunLevel Limited
        $PopupSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances Parallel -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskPath $TaskPath -TaskName $PopupTaskName -Action $PopupAction -Trigger $PopupTriggers -Principal $PopupPrincipal -Settings $PopupSettings -Description "Restart reminder after a display language change (Set-DeviceLanguage)" -ErrorAction Stop | Out-Null
        Start-ScheduledTask -TaskPath $TaskPath -TaskName $PopupTaskName -ErrorAction Stop
        Write-Output "Restart reminder popup registered and started."

        Write-Output "Language change to $Language completed. Restart reminder is shown to the user, returning 0."
        Stop-Transcript | Out-Null
        exit 0
    }
    catch {
        Write-Error "Restart reminder setup failed: $($_.Exception.Message). Falling back to 3010, Intune handles the restart."
        # Remove what was set up so far, otherwise an enforced restart could fire without a popup
        foreach ($TaskName in @($PopupTaskName, $RebootTaskName, $CleanupTaskName)) {
            Stop-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
            Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
        }
        # Stopping the task ends conhost.exe, not the PowerShell child, so end running popups directly (as in step 8.1)
        Get-CimInstance -ClassName Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like "*$PopupFileName*" } |
            ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName Terminate -ErrorAction SilentlyContinue | Out-Null }
        Remove-Item -Path $ReminderRegPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Restart reminder tasks and registry state removed."
    }
}

# Step 9: Finish and request restart through Intune
Write-Output "Language change to $Language completed. Restart required."
Stop-Transcript | Out-Null
exit 3010
