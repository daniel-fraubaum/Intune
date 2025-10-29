<#
Script: Detect Services with Missing Quotes in Path
Author: Daniel Fraubaum | headsinthecloud.blog
Version: 1.0.0
Date: 2025-10-29
Description: Intune Remediation Detection Script.
             Identifies auto-start services whose executable path is not enclosed in quotes
             and does not reside in a Windows directory. Exits 1 if such services are found,
             otherwise exits 0.
#>

########################################
# Parameters
########################################
# No static parameters required; discovery is dynamic.

########################################
# Detection Logic
########################################

$services = Get-CimInstance -ClassName Win32_Service |
    Where-Object {
        $_.StartMode -eq 'Auto' -and
        $_.PathName -notmatch 'Windows' -and
        $_.PathName -notmatch '^".*"$'
    }

if ($services.Count -gt 0) {
    $services | ForEach-Object {
        Write-Output "[Detect] Service '$($_.DisplayName)' ($($_.Name)) has unquoted path: $($_.PathName)"
    }
    Exit 1
} else {
    # Uncomment for optional output
    # Write-Output "[Detect] No auto-start services with unquoted paths found."
    Exit 0
}
