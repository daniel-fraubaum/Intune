
<#
Script: Detect SecureBoot Cert Update MicrosoftUpdateManagedOptIn
Author: Daniel Fraubaum | headsinthecloud.blog
Version: 1.0.0
Date: 2025-12-16
Description: Intune Remediation Detection Script.
             Checks if the registry value 'MicrosoftUpdateManagedOptIn'
             under HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\ is set to 1.
             Exits 0 if compliant, exits 1 if non-compliant.
#>

# ==============================
# Parameters
# ==============================
$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\"
$Key = "MicrosoftUpdateManagedOptIn"
$ExpectedValue = 1

# ==============================
# Detection Logic
# ==============================
try {
    # Check if the registry path exists
    if (Test-Path -Path $Path) {
        # Get the current value of the registry key
        $CurrentValue = (Get-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue).$Key

        # If the value equals 1, return compliant
        if ($CurrentValue -eq $ExpectedValue) {
            Write-Output "Compliant: Value is $ExpectedValue."
            exit 0
        }
        else {
            Write-Output "Non-Compliant: Value is not $ExpectedValue."
            exit 1
        }
    }
    else {
        Write-Output "Non-Compliant: Registry path does not exist."
        exit 1
    }
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}

