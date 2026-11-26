<#
    Script:      Detect_FixDesktopDeletionRight.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Detects whether standard users (BUILTIN\Users, S-1-5-32-545) have the right
                 "Delete subfolders and files" (DC) on the Public Desktop, so they can delete
                 shortcuts that installers place there for all users.
                 Also flags explicit Users rights that would let users create items, delete or
                 re-permission the folder (for example FullControl from version 1.0).
                 Exit 0 = compliant, exit 1 = remediation required.
#>

# ==== Parameters ====
# Must match the value in Remediate_FixDesktopDeletionRight.ps1
$UsersSid = "S-1-5-32-545"

# ==== Functions ====
function Get-UsersRules {
    param ([string]$Path)
    $Acl = Get-Acl -LiteralPath $Path -ErrorAction Stop
    # Explicit rules only, inherited rules cannot be changed on this folder
    $Acl.GetAccessRules($true, $false, [System.Security.Principal.SecurityIdentifier]) |
        Where-Object { $_.IdentityReference.Value -eq $UsersSid -and $_.AccessControlType -eq "Allow" }
}

# ==== Logic ====
try {
    # Step 1: Locate the Public Desktop
    $DesktopPath = [Environment]::GetFolderPath("CommonDesktopDirectory")
    if (-not $DesktopPath -or -not (Test-Path -LiteralPath $DesktopPath)) {
        Write-Output "Not compliant: Public Desktop not found"
        exit 1
    }

    # Step 2: The Public Desktop must be a real folder, not a junction or symbolic link
    $Folder = Get-Item -LiteralPath $DesktopPath -Force -ErrorAction Stop
    if ($Folder.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        Write-Output "Not compliant: $DesktopPath is a junction or symbolic link, not touched"
        exit 1
    }

    $Rules = @(Get-UsersRules -Path $DesktopPath)

    # Step 3: Users need DC on the folder itself (not inherit only)
    $DeleteChild = [int][System.Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
    $HasDeleteChild = $Rules | Where-Object {
        ([int]$_.FileSystemRights -band $DeleteChild) -and
        -not $_.PropagationFlags.HasFlag([System.Security.AccessControl.PropagationFlags]::InheritOnly)
    }
    if (-not $HasDeleteChild) {
        Write-Output "Not compliant: Users have no Delete subfolders and files (DC) right on $DesktopPath"
        exit 1
    }

    # Step 4: Users must not be able to create items (junctions), delete the folder or change permissions
    # CreateFiles 0x2, CreateDirectories 0x4, Delete 0x10000, ChangePermissions 0x40000,
    # TakeOwnership 0x80000, GenericAll 0x10000000, GenericWrite 0x40000000
    $Dangerous = 0x2 -bor 0x4 -bor 0x10000 -bor 0x40000 -bor 0x80000 -bor 0x10000000 -bor 0x40000000
    $TooMuch = $Rules | Where-Object { [int]$_.FileSystemRights -band $Dangerous }
    if ($TooMuch) {
        Write-Output "Not compliant: Users have more than DC on $DesktopPath ($(($TooMuch | ForEach-Object { $_.FileSystemRights }) -join ', '))"
        exit 1
    }

    Write-Output "Compliant: Users have Delete subfolders and files (DC) on $DesktopPath"
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
