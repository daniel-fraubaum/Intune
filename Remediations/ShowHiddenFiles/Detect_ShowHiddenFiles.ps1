<#
    Script:      Detect_ShowHiddenFiles.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-18
    Description: Detects whether hidden files and folders are shown in File Explorer.
#>

# ==== Parameters ====
$RegPath   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$ValueName = "Hidden"
$Expected  = 1

# ==== Logic ====
try {
    # Step 1: Read current value
    $Current = (Get-ItemProperty -Path $RegPath -Name $ValueName -ErrorAction Stop).$ValueName

    # Step 2: Compare with expected value
    if ($Current -eq $Expected) {
        Write-Output "Compliant: $ValueName is $Current"
        exit 0
    }
    Write-Output "Not compliant: $ValueName is $Current"
    exit 1
}
catch {
    Write-Output "Not compliant: $ValueName not found"
    exit 1
}
