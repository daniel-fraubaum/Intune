<#
    Script:      Remediate_SmartCardRemovalPolicyService.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Sets the Smart Card Removal Policy service (SCPolicySvc) to Automatic (Delayed Start)
                 and starts it.
                 Needed for the "lock on smart card / YubiKey removal" behavior on Entra joined devices.
                 Changes nothing if the removal policy (ScRemoveOption) is not configured, the service
                 stops without it.
#>

# ==============================
# Parameters
# ==============================

$ServiceName = "SCPolicySvc"
$RegPath     = "HKLM:\SYSTEM\CurrentControlSet\Services\$ServiceName"

# Policy "Interactive logon: Smart card removal behavior" (REG_SZ, "0" = no action, "1" = lock, "2" = force logoff, "3" = disconnect RDP)
$PolicyPath  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$PolicyName  = "ScRemoveOption"
$ValidPolicy = @("1", "2", "3")

# ==============================
# Remediation Logic
# ==============================

try {
    # Step 0: Without the removal policy SCPolicySvc stops right after the start, so change nothing
    $Policy = "$((Get-ItemProperty -Path $PolicyPath -Name $PolicyName -ErrorAction SilentlyContinue).$PolicyName)".Trim()
    if ($ValidPolicy -notcontains $Policy) {
        Write-Output "Not remediated: smart card removal policy (ScRemoveOption) is not configured. Assign the policy Interactive logon: Smart card removal behavior to this device."
        exit 1
    }

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
