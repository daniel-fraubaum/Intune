<#
    Script:      Smart Card Removal Policy Service Remediation
    Author:      Daniel Fraubaum | headsinthecloud.blog
    Version:     1.0.0
    Date:        2026-04-13

    Description: Intune Remediation Script.
    Ensures that the Smart Card Removal Policy service (SCPolicySvc) is set to
    Automatic (Delayed Start) and is running.
    Required for Smart Card / YubiKey removal lock behavior on Entra-joined devices.
#>

# ==============================
# Parameters
# ==============================

$ServiceName = "SCPolicySvc"
$RegPath     = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"

# ==============================
# Remediation Logic
# ==============================

try {
    # Step 1: Verify service exists
    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        Write-Error "Remediation failed: Service '$ServiceName' not found on this device."
        exit 1
    }

    # Step 2: Set startup type to Automatic (Delayed Start)
    Set-ItemProperty -Path $RegPath -Name "Start" -Value 2 -Type DWord -ErrorAction Stop
    Set-ItemProperty -Path $RegPath -Name "DelayedAutostart" -Value 1 -Type DWord -ErrorAction Stop
    Write-Output "Remediation applied: Service '$ServiceName' set to Automatic (Delayed Start)."

    # Step 3: Start service if not running
    $service = Get-Service -Name $ServiceName
    if ($service.Status -ne 'Running') {
        Start-Service -Name $ServiceName -ErrorAction Stop
        Write-Output "Remediation applied: Service '$ServiceName' started successfully."
    }
    else {
        Write-Output "No action required: Service '$ServiceName' is already running."
    }
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
