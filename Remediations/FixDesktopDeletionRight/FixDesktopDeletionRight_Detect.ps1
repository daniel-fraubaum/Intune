<#
    Script:      FixDesktopDeletionRight_Detect.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.0
    Date:        2026-11-26
    Description: Detects whether standard users (BUILTIN\Users, S-1-5-32-545) have the configured right
                 on the Public Desktop, inherited to all subfolders and files, so they can delete
                 shortcuts that installers place there for all users.
                 Exit 0 = compliant, exit 1 = remediation required.
#>

# ==== Parameters ====
# Must match the value in FixDesktopDeletionRight_Remediate.ps1. "FullControl" or "Modify"
$Rights   = "FullControl"
$UsersSid = "S-1-5-32-545"

# ==== Functions ====
function Test-UsersRight {
    param (
        [string]$Path,
        [switch]$RequireInheritance
    )
    $Needed = [System.Security.AccessControl.FileSystemRights]$Rights
    $Acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    foreach ($Rule in $Acl.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])) {
        if ($Rule.IdentityReference.Value -ne $UsersSid -or $Rule.AccessControlType -ne "Allow") { continue }
        if (($Rule.FileSystemRights -band $Needed) -ne $Needed) { continue }
        if ($RequireInheritance) {
            $Inherits = $Rule.InheritanceFlags.HasFlag([System.Security.AccessControl.InheritanceFlags]::ContainerInherit) -and
                        $Rule.InheritanceFlags.HasFlag([System.Security.AccessControl.InheritanceFlags]::ObjectInherit)
            $InheritOnly = $Rule.PropagationFlags.HasFlag([System.Security.AccessControl.PropagationFlags]::InheritOnly)
            if (-not $Inherits -or $InheritOnly) { continue }
        }
        return $true
    }
    return $false
}

# ==== Logic ====
try {
    # Step 1: Locate the Public Desktop
    $DesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
    if (-not $DesktopPath -or -not (Test-Path -LiteralPath $DesktopPath)) {
        Write-Output "Not compliant: Public Desktop not found"
        exit 1
    }

    # Step 2: The folder itself needs the right, inherited to subfolders and files
    if (-not (Test-UsersRight -Path $DesktopPath -RequireInheritance)) {
        Write-Output "Not compliant: Users have no inherited $Rights on $DesktopPath"
        exit 1
    }

    # Step 3: Every existing item needs the right too (items with broken inheritance)
    $Missing = @(Get-ChildItem -LiteralPath $DesktopPath -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-UsersRight -Path $_.FullName) })
    if ($Missing.Count -gt 0) {
        Write-Output "Not compliant: $($Missing.Count) item(s) without $Rights for Users, e.g. $($Missing[0].Name)"
        exit 1
    }

    Write-Output "Compliant: Users have $Rights on $DesktopPath and all items"
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
