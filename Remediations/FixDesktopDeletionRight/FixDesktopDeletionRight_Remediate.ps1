<#
    Script:      FixDesktopDeletionRight_Remediate.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-26
    Description: Grants standard users (BUILTIN\Users, S-1-5-32-545) the configured right on the
                 Public Desktop with icacls, inherited to subfolders and files (OI)(CI) and applied
                 to all existing items (/T), so they can delete shortcuts that installers place
                 there for all users.
#>

# ==== Parameters ====
# Must match the value in FixDesktopDeletionRight_Detect.ps1. "FullControl" or "Modify"
$Rights   = "FullControl"
$UsersSid = "S-1-5-32-545"
$LogFile  = "$env:SystemRoot\Logs\FixDesktopDeletionRight.log"

# ==== Logic ====
Start-Transcript -Path $LogFile -Append | Out-Null
$ExitCode = 0
try {
    # Step 1: Locate the Public Desktop
    $DesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
    if (-not $DesktopPath -or -not (Test-Path -LiteralPath $DesktopPath)) {
        throw "Public Desktop not found"
    }

    # Step 2: Map the right to icacls notation
    $IcaclsRights = @{ FullControl = "F"; Modify = "M" }
    if (-not $IcaclsRights.ContainsKey($Rights)) {
        throw "Unsupported value for Rights: $Rights. Use FullControl or Modify"
    }
    $Grant = "*$($UsersSid):(OI)(CI)$($IcaclsRights[$Rights])"

    # Step 3: Grant the right on the folder and all existing items
    Write-Output "Running: icacls `"$DesktopPath`" /grant $Grant /T /C"
    $Output = & "$env:SystemRoot\System32\icacls.exe" $DesktopPath /grant $Grant /T /C 2>&1
    $IcaclsExitCode = $LASTEXITCODE
    $Output | ForEach-Object { Write-Output "$_" }

    if ($IcaclsExitCode -ne 0) {
        Write-Error "icacls failed with exit code $IcaclsExitCode"
        $ExitCode = 1
    }
    else {
        Write-Output "Remediated: Users have $Rights on $DesktopPath and all items"
    }
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    $ExitCode = 1
}

Stop-Transcript | Out-Null
exit $ExitCode
