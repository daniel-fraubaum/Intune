<#
    Script:      Remediate_AdobeSecureScoreSettings.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Sets the Adobe Acrobat and Reader lockdown settings for Microsoft Secure Score:
                 Flash off, JavaScript off and Protected Mode on. Writes missing or wrong
                 FeatureLockDown values as DWORD under HKLM\SOFTWARE\Policies\Adobe and logs
                 every change.
#>

# ==== Parameters ====
# Must match the list in Detect_AdobeSecureScoreSettings.ps1
$Settings = @(
    @{ Product = "Acrobat Reader"; Version = "DC"; Name = "bEnableFlash";       Value = 0 }
    @{ Product = "Acrobat Reader"; Version = "DC"; Name = "bDisableJavaScript"; Value = 1 }
    @{ Product = "Acrobat Reader"; Version = "DC"; Name = "bProtectedMode";     Value = 1 }
    @{ Product = "Adobe Acrobat";  Version = "DC"; Name = "bDisableJavaScript"; Value = 1 }
    @{ Product = "Adobe Acrobat";  Version = "DC"; Name = "bProtectedMode";     Value = 1 }
)

# HKLM\SOFTWARE\Policies is shared between 32-bit and 64-bit, WOW6432Node\Policies is the same key
$PolicyRoot = "HKLM:\SOFTWARE\Policies\Adobe"

# IME log folder, so the log is part of "Collect diagnostics" in the Intune admin center
$LogFile      = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs\AdobeSecureScoreSettings.log"
$MaxLogSizeKB = 1024

# ==== Logic ====
$LogFolder = Split-Path -Path $LogFile -Parent
if (-not (Test-Path -LiteralPath $LogFolder)) {
    New-Item -ItemType Directory -Path $LogFolder -Force | Out-Null
}
# Keep one old log, so the transcript does not grow forever
if ((Test-Path -LiteralPath $LogFile) -and (Get-Item -LiteralPath $LogFile).Length -gt ($MaxLogSizeKB * 1KB)) {
    Move-Item -LiteralPath $LogFile -Destination "$LogFile.old" -Force -ErrorAction SilentlyContinue
}
Start-Transcript -Path $LogFile -Append | Out-Null
$ExitCode = 0
try {
    $Changed = 0
    foreach ($Setting in $Settings) {
        $KeyPath = "$PolicyRoot\$($Setting.Product)\$($Setting.Version)\FeatureLockDown"
        $Label   = "$($Setting.Product)\$($Setting.Version)\$($Setting.Name)"

        # Step 1: Create the key only if missing, New-Item -Force would empty an existing key
        if (-not (Test-Path -Path $KeyPath)) {
            New-Item -Path $KeyPath -Force -ErrorAction Stop | Out-Null
        }

        # Step 2: Read the current value
        $Key = Get-Item -Path $KeyPath -ErrorAction Stop
        if ($Key.GetValueNames() -contains $Setting.Name) {
            $Kind    = $Key.GetValueKind($Setting.Name)
            $Current = "$($Key.GetValue($Setting.Name)) ($Kind)"
            if ($Kind -eq [Microsoft.Win32.RegistryValueKind]::DWord -and $Key.GetValue($Setting.Name) -eq $Setting.Value) {
                Write-Output "OK:  $Label = $($Setting.Value)"
                continue
            }
        }
        else {
            $Current = "missing"
        }

        # Step 3: Write the value as DWORD
        New-ItemProperty -Path $KeyPath -Name $Setting.Name -Value $Setting.Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        Write-Output "Set: $Label = $($Setting.Value) (was $Current)"
        $Changed++
    }

    Write-Output "Remediated: $Changed of $($Settings.Count) Adobe lockdown values set"
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    $ExitCode = 1
}

Stop-Transcript | Out-Null
exit $ExitCode
