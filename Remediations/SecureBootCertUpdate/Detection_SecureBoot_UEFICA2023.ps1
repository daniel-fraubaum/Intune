
<#
Script: SecureBoot CA 2023 Detection
Author: Daniel Fraubaum
Version: 1.1.0
Date: 2025-12-17
Description:
Checks if Secure Boot CA 2023 update is applied by validating registry keys first,
then confirming presence of Windows UEFI CA 2023 certificate in Secure Boot DB.
Exit codes: 0 = Compliant, 1 = Non-Compliant.
#>

# ==============================
# Parameters
# ==============================
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\Servicing"

# ==============================
# Helper Function
# ==============================
function Get-RegistryValue {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Key
    )

    # Return null if path does not exist
    if (-not (Test-Path $Path)) { return $null }

    try {
        (Get-ItemProperty -Path $Path -Name $Key -ErrorAction Stop).$Key
    } catch {
        $null
    }
}

# ==============================
# Detection Logic
# ==============================

# Step 1: Check registry for update status
$status  = Get-RegistryValue -Path $regPath -Key "UEFICA2023Status"
$error   = Get-RegistryValue -Path $regPath -Key "UEFICA2023Error"
$capable = Get-RegistryValue -Path $regPath -Key "WindowsUEFICA2023Capable"

if (($status -eq "Updated" -or $capable -eq 2) -and ($null -eq $error -or $error -eq 0)) {
    Write-Output "Compliant: Registry indicates Secure Boot CA 2023 update applied (Status='$status', Capable=$capable, Error=$error)."
    exit 0
}

# Step 2: Check Secure Boot UEFI database for certificate
try {
    $db = Get-SecureBootUEFI -Name db
    $dbString = [System.Text.Encoding]::ASCII.GetString($db.Bytes)
    if ($dbString -match 'Windows UEFI CA 2023') {
        Write-Output "Compliant: Windows UEFI CA 2023 certificate found in Secure Boot DB."
        exit 0
    } else {
        Write-Output "Non-Compliant: Certificate not found in Secure Boot DB."
        exit 1
    }
} catch {
    Write-Output "Error: Unable to access Secure Boot UEFI DB. Device may not support Secure Boot or access is restricted."
    exit 1
}
