<#
    Script:      Detect_SecureBootCertUpdate_OptIn.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2025-12-16
    Description: Detects whether the device is opted in to the Microsoft managed Secure Boot
                 certificate update (MicrosoftUpdateManagedOptIn = 1 under
                 HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot).
                 Exit 0 = compliant, exit 1 = remediation required.
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

