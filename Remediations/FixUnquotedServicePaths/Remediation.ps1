<#
Script: Fix Unquoted Service Paths
Author: Daniel Fraubaum | headsinthecloud.blog
Version: 1.0.0
Date: 2025-10-29
Description: Intune Remediation Script.
             Identifies and corrects unquoted paths in auto-start services and uninstall strings.
#>

########################################
# Parameters
########################################

Param (
    [Bool]$FixServices = $true,
    [Switch]$FixUninstall,
    [Switch]$FixEnv,
    [Switch]$Passthru,
    [Switch]$Silent
)

########################################
# Remediation Logic
########################################

Function Fix-ServicePath {
    Param (
        [bool]$FixServices = $true,
        [Switch]$FixUninstall,
        [Switch]$FixEnv,
        [Switch]$Passthru
    )

    $FixParameters = @()
    If ($FixServices) {
        $FixParameters += @{"Path" = "HKLM:\SYSTEM\CurrentControlSet\Services\" ; "ParamName" = "ImagePath"}
    }
    If ($FixUninstall) {
        $FixParameters += @{"Path" = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\" ; "ParamName" = "UninstallString"}
        If (Test-Path "$($env:SystemDrive)\Program Files (x86)\") {
            $FixParameters += @{"Path" = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\" ; "ParamName" = "UninstallString"}
        }
    }

    $PTElements = @()
    ForEach ($FixParameter in $FixParameters) {
        Get-ChildItem $FixParameter.Path -ErrorAction SilentlyContinue | ForEach-Object {
            $RegistryPath = $_.name -Replace 'HKEY_LOCAL_MACHINE', 'HKLM:'
            $OriginalPath = Get-ItemProperty "$RegistryPath"
            $ImagePath = $OriginalPath.$($FixParameter.ParamName)

            If ($FixEnv -and ($ImagePath -match '%(?''envVar''[^%]+)%')) {
                $EnvVar = $Matches['envVar']
                $FullVar = (Get-ChildItem env: | Where-Object {$_.Name -eq $EnvVar}).value
                $ImagePath = $ImagePath -replace "%$EnvVar%", $FullVar
                Clear-Variable Matches
            }

            If (($ImagePath -like "* *") -and ($ImagePath -notLike '"*"*') -and ($ImagePath -like '*.exe*')) {
                If ((($FixParameter.ParamName -eq 'UninstallString') -and ($ImagePath -NotMatch 'MsiExec(\.exe)?')) -or ($FixParameter.ParamName -eq 'ImagePath')) {
                    $NewPath = ($ImagePath -split ".exe ")[0]
                    $key = ($ImagePath -split ".exe ")[1]
                    $trigger = ($ImagePath -split ".exe ")[2]
                    $NewValue = ''

                    If (-not ($trigger | Measure-Object).count -ge 1) {
                        If (($NewPath -like "* *") -and ($NewPath -notLike "*.exe")) {
                            $NewValue = "`"$NewPath.exe`" $key"
                        } ElseIf (($NewPath -like "* *") -and ($NewPath -like "*.exe")) {
                            $NewValue = "`"$NewPath`""
                        }

                        If (-not [string]::IsNullOrEmpty($NewValue)) {
                            try {
                                $OriginalPSPath = $OriginalPath.PSPath
                                Set-ItemProperty -Path $OriginalPSPath -Name $FixParameter.ParamName -Value $NewValue -ErrorAction Stop
                                If ($Passthru) {
                                    $PTElements += '' | Select-Object `
                                        @{n = 'Name'; e = {$OriginalPath.PSChildName}}, `
                                        @{n = 'ParamName'; e = {$FixParameter.ParamName}}, `
                                        @{n = 'OriginalValue'; e = {$ImagePath}}, `
                                        @{n = 'ExpectedValue'; e = {$NewValue}}
                                }
                            } Catch {
                                Write-Output "ERROR: Failed to update '$($OriginalPath.PSChildName)'"
                            }
                        }
                    }
                }
            }
        }
    }

    If ($Passthru) {
        return $PTElements
    }
}

########################################
# Execution
########################################

If ((! $FixServices) -and (! $FixUninstall)) {
    Throw "At least one of FixServices or FixUninstall must be selected."
}

$Result = Fix-ServicePath `
    -FixServices:$FixServices `
    -FixUninstall:$FixUninstall `
    -FixEnv:$FixEnv `
    -Passthru:$Passthru

If ($Passthru -and $Result) {
    If ($Silent) {
        $True
    } Else {
        $Result
    }
}
