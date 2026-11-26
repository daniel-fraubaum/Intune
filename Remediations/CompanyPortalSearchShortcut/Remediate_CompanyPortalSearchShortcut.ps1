<#
    Script:      Remediate_CompanyPortalSearchShortcut.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.2
    Date:        2026-11-26
    Description: Creates an English-named Company Portal shortcut in the All Users Start Menu,
                 so Start search finds "Intune" and "Company Portal" on non-English clients.
                 The icon is taken from the installed Company Portal package.
#>

# ==== Parameters ====
$ShortcutName   = "Intune Company Portal"
$PackageName    = "Microsoft.CompanyPortal"
$AppUserModelId = "Microsoft.CompanyPortal_8wekyb3d8bbwe!App"
$StartMenuPath  = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
# Program Files, not ProgramData: standard users can create folders in ProgramData and would own them
$IconFolder     = "$env:ProgramFiles\CompanyPortalSearchShortcut"

# ==== Logic ====
try {
    # Step 1: Find the installed Company Portal package
    $Package = Get-AppxPackage -AllUsers -Name $PackageName -ErrorAction SilentlyContinue |
        Sort-Object -Property Version -Descending | Select-Object -First 1
    if (-not $Package) {
        Write-Output "$PackageName not installed, nothing to do"
        exit 0
    }

    # Step 2: Find the largest unplated app logo in the package
    $IconFile = Join-Path $IconFolder "CompanyPortal.ico"
    [xml]$Manifest = Get-Content -Path (Join-Path $Package.InstallLocation "AppxManifest.xml") -Raw
    $LogoRelative = $Manifest.SelectSingleNode("//*[local-name()='VisualElements']").GetAttribute("Square44x44Logo")
    $LogoBase     = [System.IO.Path]::GetFileNameWithoutExtension($LogoRelative)
    $LogoDir      = Join-Path $Package.InstallLocation ([System.IO.Path]::GetDirectoryName($LogoRelative))

    $Candidates = @(Get-ChildItem -Path $LogoDir -Filter "$LogoBase*.png" -File | Where-Object { $_.Name -notmatch "contrast" })
    $Unplated   = @($Candidates | Where-Object { $_.Name -match "altform-unplated" -and $_.Name -notmatch "lightunplated" })
    if ($Unplated.Count -gt 0) { $Candidates = $Unplated }
    $LogoFile = $Candidates | Sort-Object -Property Length -Descending | Select-Object -First 1

    # Step 3: Convert the PNG logo into an ICO file (PNG embedded in ICO container)
    if ($LogoFile) {
        if (-not (Test-Path -Path $IconFolder)) {
            New-Item -Path $IconFolder -ItemType Directory -Force | Out-Null
        }
        # Never write the icon through a junction or symbolic link
        if ((Get-Item -LiteralPath $IconFolder -Force).Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "$IconFolder is a junction or symbolic link, icon not written"
        }

        $PngBytes = [System.IO.File]::ReadAllBytes($LogoFile.FullName)
        $Width    = [System.BitConverter]::ToInt32([byte[]]$PngBytes[19..16], 0)
        $Height   = [System.BitConverter]::ToInt32([byte[]]$PngBytes[23..20], 0)

        $Stream = New-Object System.IO.MemoryStream
        $Writer = New-Object System.IO.BinaryWriter($Stream)
        $Writer.Write([UInt16]0)
        $Writer.Write([UInt16]1)
        $Writer.Write([UInt16]1)
        $Writer.Write([byte]$(if ($Width -ge 256) { 0 } else { $Width }))
        $Writer.Write([byte]$(if ($Height -ge 256) { 0 } else { $Height }))
        $Writer.Write([byte]0)
        $Writer.Write([byte]0)
        $Writer.Write([UInt16]1)
        $Writer.Write([UInt16]32)
        $Writer.Write([UInt32]$PngBytes.Length)
        $Writer.Write([UInt32]22)
        $Writer.Write($PngBytes)
        $Writer.Flush()
        [System.IO.File]::WriteAllBytes($IconFile, $Stream.ToArray())
        $Writer.Dispose()
    }
    else {
        Write-Output "Warning: no logo found in $LogoDir, shortcut gets the default icon"
    }

    # Step 4: Recreate the shortcut from scratch
    $ShortcutFile = Join-Path $StartMenuPath "$ShortcutName.lnk"
    if (Test-Path -Path $ShortcutFile) {
        Remove-Item -Path $ShortcutFile -Force
    }

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($ShortcutFile)
    $Shortcut.TargetPath  = "$env:WINDIR\explorer.exe"
    $Shortcut.Arguments   = "shell:AppsFolder\$AppUserModelId"
    $Shortcut.Description = $ShortcutName
    if (Test-Path -Path $IconFile) {
        $Shortcut.IconLocation = "$IconFile,0"
    }
    $Shortcut.Save()

    Write-Output "Shortcut created: $ShortcutFile"
    exit 0
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
