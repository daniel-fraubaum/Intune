
<#
.SCRIPT NAME:    Detection-SecureBoot-OptIn.ps1
.AUTHOR:         Fraubaum Daniel | base-IT
.VERSION:        1.0
.DATE:           16.12.2025
.DESCRIPTION:    This script checks if the registry value 
                 'MicrosoftUpdateManagedOptIn' under 
                 HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\ 
                 is set to 1. If yes, it returns compliant (exit code 0),
                 otherwise non-compliant (exit code 1).
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
