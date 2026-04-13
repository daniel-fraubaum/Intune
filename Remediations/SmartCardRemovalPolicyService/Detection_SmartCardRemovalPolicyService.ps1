<#
    Script:      Smart Card Removal Policy Service Detection
    Author:      Daniel Fraubaum | headsinthecloud.blog
    Version:     1.0.0
    Date:        2026-04-13

    Description:
    Checks if the Smart Card Removal Policy service (SCPolicySvc) is set to
    Automatic (Delayed Start) and is currently running.
    Required for Smart Card / YubiKey removal lock behavior on Entra-joined devices.

    Exit codes: 0 = Compliant, 1 = Non-Compliant.
#>

# ==============================
# Parameters
# ==============================

$ServiceName = "SCPolicySvc"

# ==============================
# Detection Logic
# ==============================

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
