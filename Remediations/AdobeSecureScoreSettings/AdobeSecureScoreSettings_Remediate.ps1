<#
    Script:      AdobeSecureScoreSettings_Remediate.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-26
    Description: Sets the Adobe Acrobat and Reader lockdown settings for Microsoft Secure Score:
                 Flash off, JavaScript off and Protected Mode on. Writes the FeatureLockDown values
                 as DWORD to the 64-bit and the 32-bit (WOW6432Node) policy path.
#>

# ==== Parameters ====
# Must match the list in AdobeSecureScoreSettings_Detect.ps1
$Settings = @(
    @{ Product = "Acrobat Reader"; Version = "DC";   Name = "bEnableFlash";       Value = 0 }
    @{ Product = "Acrobat Reader"; Version = "DC";   Name = "bDisableJavaScript"; Value = 1 }
    @{ Product = "Acrobat Reader"; Version = "DC";   Name = "bProtectedMode";     Value = 1 }
    @{ Product = "Adobe Acrobat";  Version = "DC";   Name = "bDisableJavaScript"; Value = 1 }
    @{ Product = "Adobe Acrobat";  Version = "DC";   Name = "bProtectedMode";     Value = 1 }
    @{ Product = "Acrobat Reader"; Version = "2017"; Name = "bDisableJavaScript"; Value = 1 }
    @{ Product = "Adobe Acrobat";  Version = "2017"; Name = "bDisableJavaScript"; Value = 1 }
    @{ Product = "Acrobat";        Version = "2017"; Name = "bDisableJavaScript"; Value = 1 }
)

# 64-bit and 32-bit policy path, Adobe reads the one that matches the installed product
$PolicyRoots = @(
    "HKLM:\SOFTWARE\Policies\Adobe",
    "HKLM:\SOFTWARE\WOW6432Node\Policies\Adobe"
)

# ==== Logic ====
try {
    foreach ($Root in $PolicyRoots) {
        foreach ($Setting in $Settings) {
            $KeyPath = "$Root\$($Setting.Product)\$($Setting.Version)\FeatureLockDown"

            # Step 1: Create the key only if missing, New-Item -Force would empty an existing key
            if (-not (Test-Path -Path $KeyPath)) {
                New-Item -Path $KeyPath -Force -ErrorAction Stop | Out-Null
            }

            # Step 2: Write the value as DWORD
            New-ItemProperty -Path $KeyPath -Name $Setting.Name -Value $Setting.Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        }
    }

    Write-Output "Remediated: $($Settings.Count * $PolicyRoots.Count) Adobe lockdown values set"
    exit 0
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
