<#
    Script:      Set-DeviceLanguage.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.2
    Date:        2026-11-23
    Description: Installs a Windows display language and applies display language, preferred
                 language list, regional format and country/region.
                 Settings are copied to the Welcome screen and new user profiles. If a user is
                 signed in, the settings are also applied to that user via a one-time scheduled
                 task in user context (existing languages and keyboards are kept).
                 Built as Intune Win32 app in SYSTEM context for Autopilot ESP (required, with
                 -InitialSetup) and Company Portal (available). Exit code 3010 signals that a
                 restart is required.
                 Before Install-Language the script waits until no other servicing operation
                 (for example a cumulative update) is running. If servicing stays busy, a reboot
                 is pending or Install-Language fails, the script returns exit code 1618 so that
                 Intune retries the installation instead of failing it.
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
    [switch]$InitialSetup
)

# Registry key for the Intune detection markers
$MarkerKeyPath = "HKLM:\SOFTWARE\CompanyName\DeviceLanguage"

# Marker value for the Company Portal apps (last selected language)
$MarkerValueName = "Language"

# Marker value for the Autopilot app (written only with -InitialSetup, never changed afterwards)
$InitialMarkerValueName = "InitialLanguage"

# Working folder for the temporary user script
$WorkingFolder = "$env:ProgramData\DeviceLanguage"

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

# ==========================================================================================
# Logic
# ==========================================================================================

# Step 1: Start logging
Start-Transcript -Path $LogFile -Append | Out-Null
Write-Output "Starting Set-DeviceLanguage. Language: $Language, Culture: $Culture, GeoId: $GeoId"

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

foreach ($Tag in @($Language, $Culture)) {
    try {
        [System.Globalization.CultureInfo]::GetCultureInfo($Tag) | Out-Null
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

# Step 3: Install language pack and language features if missing
$InstalledLanguage = Get-InstalledLanguage -Language $Language -ErrorAction SilentlyContinue
if ($InstalledLanguage) {
    Write-Output "Language $Language is already installed. Skipping installation."
}
else {
    # Step 3.1: Stop if a reboot from a previous servicing operation is pending
    $PendingRebootKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    )
    $PendingReboot = $PendingRebootKeys | Where-Object { Test-Path -Path $_ }
    if ($PendingReboot) {
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

    # Step 3.3: Install language, any failure is returned as retry (prerequisites are already checked)
    try {
        Write-Output "Installing language $Language. This can take up to 20 minutes."
        Install-Language -Language $Language -ErrorAction Stop | Out-Null
        Write-Output "Language $Language installed successfully."
    }
    catch {
        $ErrorMessage = $_.Exception.Message
        $ErrorCode = ""
        if ($ErrorMessage -match "ErrorCode:\s*(-?\d+)") {
            $ErrorCode = " (0x{0:X8})" -f [int]$Matches[1]
        }
        $RebootAfterFailure = $PendingRebootKeys | Where-Object { Test-Path -Path $_ }
        if ($RebootAfterFailure) {
            $ErrorMessage += " Reboot is pending now, a parallel update was probably installed."
        }
        Write-Error "Installation of language $Language failed$ErrorCode`: $ErrorMessage Returning $RetryExitCode for Intune retry."
        Stop-Transcript | Out-Null
        exit $RetryExitCode
    }
}

# Step 4: Apply settings to the SYSTEM account (source for Welcome screen and new users)
try {
    Set-WinUILanguageOverride -Language $Language -ErrorAction Stop
    $SystemLanguageList = New-WinUserLanguageList -Language $Language
    Set-WinUserLanguageList -LanguageList $SystemLanguageList -Force -ErrorAction Stop
    Set-Culture -CultureInfo $Culture -ErrorAction Stop
    if ($GeoId -gt 0) {
        Set-WinHomeLocation -GeoId $GeoId -ErrorAction Stop
    }
    Set-WinSystemLocale -SystemLocale $Language -ErrorAction Stop
    Write-Output "System settings applied (display language, language list, regional format, region, system locale)."
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

if (-not $SignedInUsers) {
    Write-Output "No signed-in user found. User part skipped, new profiles get the settings from step 5."
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
    # Put the new language first and keep existing languages and keyboards
    $CurrentList = Get-WinUserLanguageList
    $NewList = New-WinUserLanguageList -Language $Language
    foreach ($Item in $CurrentList) {
        if ($Item.LanguageTag -ne $NewList[0].LanguageTag) {
            $NewList.Add($Item)
        }
    }
    Set-WinUserLanguageList -LanguageList $NewList -Force -ErrorAction Stop
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
    New-Item -Path $MarkerKeyPath -Force | Out-Null
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

# Step 8: Finish and request restart
Write-Output "Language change to $Language completed. Restart required."
Stop-Transcript | Out-Null
exit 3010
