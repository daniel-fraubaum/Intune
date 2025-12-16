
<#
.SCRIPT NAME:    Remediation-SecureBoot-OptIn.ps1
.AUTHOR:         Fraubaum Daniel | base-IT
.VERSION:        1.0
.DATE:           16.12.2025
.DESCRIPTION:    This script checks if the registry value 
                 'MicrosoftUpdateManagedOptIn' under 
                 HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\ 
                 is set to 1. If not, it remediates the value.
#>

# ==============================
# Parameters
# ==============================
$Path = "HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\"
$Key = "MicrosoftUpdateManagedOptIn"
$ExpectedValue = 1
$KeyFormat = "DWORD"

# ==============================
# Remediation Logic
# ==============================
try {
    # Check if the registry path exists, create if missing
    if (!(Test-Path -Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    # Get the current value of the registry key
    $CurrentValue = (Get-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue).$Key

    # If the value is missing or not equal to 1, set it to 1
    if ($null -eq $CurrentValue -or $CurrentValue -ne $ExpectedValue) {
        Set-ItemProperty -Path $Path -Name $Key -Value $ExpectedValue -Type $KeyFormat
        Write-Output "Remediation applied: Value set to $ExpectedValue."
    }
    else {
        Write-Output "No action required: Value is already correct ($ExpectedValue)."
    }
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
}
