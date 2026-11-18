<#
    Script:      ShowHiddenFiles_Remediate.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-18
    Description: Shows hidden files and folders in File Explorer.
#>

# ==== Parameters ====
$RegPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$ValueName = "Hidden"
$Value     = 1

# ==== Logic ====
try {
    # Step 1: Ensure registry path exists
    if (-not (Test-Path -Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
    }

    # Step 2: Set value
    Set-ItemProperty -Path $RegPath -Name $ValueName -Value $Value -Type DWord -Force

    Write-Output "Remediated: $ValueName set to $Value"
    exit 0
}
catch {
    Write-Error "Failed to set ${ValueName}: $($_.Exception.Message)"
    exit 1
}
