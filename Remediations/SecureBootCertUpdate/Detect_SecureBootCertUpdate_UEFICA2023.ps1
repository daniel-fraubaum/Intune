<#
    Script:      Detect_SecureBootCertUpdate_UEFICA2023.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2025-12-17
    Description: Detection only, no remediation. Checks whether the Secure Boot CA 2023 update is
                 applied: first the servicing status in the registry, then the Windows UEFI CA 2023
                 certificate in the Secure Boot db.
                 Exit 0 = compliant, exit 1 = not compliant.
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
$errorVal   = Get-RegistryValue -Path $regPath -Key "UEFICA2023Error"
$capable = Get-RegistryValue -Path $regPath -Key "WindowsUEFICA2023Capable"

if (($status -eq "Updated" -or $capable -eq 2) -and ($null -eq $errorVal -or $errorVal -eq 0)) {
    Write-Output "Compliant: Registry indicates Secure Boot CA 2023 update applied (Status='$status', Capable=$capable, Error=$errorVal)."
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
