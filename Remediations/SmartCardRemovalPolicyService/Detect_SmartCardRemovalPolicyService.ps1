<#
    Script:      Detect_SmartCardRemovalPolicyService.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Detects whether the Smart Card Removal Policy service (SCPolicySvc) starts
                 automatically (Automatic or Automatic (Delayed Start)) and is running.
                 Needed for the "lock on smart card / YubiKey removal" behavior on Entra joined devices.
                 Checks the removal policy (ScRemoveOption) first, the service stops without it.
                 Exit 0 = compliant, exit 1 = remediation required.
#>

# ==============================
# Parameters
# ==============================

$ServiceName = "SCPolicySvc"

# Policy "Interactive logon: Smart card removal behavior" (REG_SZ, "0" = no action, "1" = lock, "2" = force logoff, "3" = disconnect RDP)
$PolicyPath  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$PolicyName  = "ScRemoveOption"
$ValidPolicy = @("1", "2", "3")

# ==============================
# Detection Logic
# ==============================

# Step 0: Check the removal policy, SCPolicySvc stops right after the start without it
$Policy = "$((Get-ItemProperty -Path $PolicyPath -Name $PolicyName -ErrorAction SilentlyContinue).$PolicyName)".Trim()
if ($ValidPolicy -notcontains $Policy) {
    Write-Output "Not compliant: smart card removal policy (ScRemoveOption) is not configured, SCPolicySvc stops without it"
    exit 1
}

# Step 1: Check if the service exists
$service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

if ($null -eq $service) {
    Write-Output "Non-Compliant: Service '$ServiceName' not found on this device."
    exit 1
}

# Step 2: Check startup type (accept both Automatic and AutomaticDelayedStart)
$startType = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" -Name "Start" -ErrorAction SilentlyContinue).Start
$delayedStart = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName" -Name "DelayedAutostart" -ErrorAction SilentlyContinue).DelayedAutostart

# Start value 2 = Automatic, DelayedAutostart 1 = Delayed
$isAutomatic = ($startType -eq 2)
$isDelayed = ($delayedStart -eq 1)

if (-not $isAutomatic) {
    Write-Output "Non-Compliant: Service '$ServiceName' startup type is not set to Automatic (Start=$startType)."
    exit 1
}

# Step 3: Check if service is running
if ($service.Status -ne 'Running') {
    Write-Output "Non-Compliant: Service '$ServiceName' is not running (Status=$($service.Status))."
    exit 1
}

# All checks passed
Write-Output "Compliant: Service '$ServiceName' is set to Automatic (Delayed=$isDelayed) and running."
exit 0
