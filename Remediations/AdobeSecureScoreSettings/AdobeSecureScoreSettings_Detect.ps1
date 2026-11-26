<#
    Script:      AdobeSecureScoreSettings_Detect.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-26
    Description: Detects whether the Adobe Acrobat and Reader lockdown settings for Microsoft Secure Score
                 are set: Flash off, JavaScript off and Protected Mode on. Checks the FeatureLockDown
                 keys in the 64-bit and the 32-bit (WOW6432Node) policy path.
                 Exit 0 = compliant, exit 1 = remediation required.
#>

# ==== Parameters ====
# Must match the list in AdobeSecureScoreSettings_Remediate.ps1
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
    # Step 1: Compare every setting in both policy paths
    $Wrong = @()
    foreach ($Root in $PolicyRoots) {
        foreach ($Setting in $Settings) {
            $KeyPath = "$Root\$($Setting.Product)\$($Setting.Version)\FeatureLockDown"
            $Key = Get-Item -Path $KeyPath -ErrorAction SilentlyContinue
            $IsCorrect = $Key -and
                         ($Key.GetValueNames() -contains $Setting.Name) -and
                         ($Key.GetValueKind($Setting.Name) -eq [Microsoft.Win32.RegistryValueKind]::DWord) -and
                         ($Key.GetValue($Setting.Name) -eq $Setting.Value)
            if (-not $IsCorrect) {
                $Wrong += "$KeyPath\$($Setting.Name)"
            }
        }
    }

    # Step 2: Report the result
    if ($Wrong.Count -gt 0) {
        Write-Output "Not compliant: $($Wrong.Count) value(s) missing or wrong, e.g. $($Wrong[0])"
        exit 1
    }

    Write-Output "Compliant: all $($Settings.Count * $PolicyRoots.Count) Adobe lockdown values are set"
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
