<#
    Script:      Remediate_SecureBootCertUpdate_OptIn.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2025-12-16
    Description: Opts the device in to the Microsoft managed Secure Boot certificate update by
                 setting MicrosoftUpdateManagedOptIn = 1 (DWORD) under
                 HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot.
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

