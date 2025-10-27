<#
Script: Disable NetBIOS - Remediation Script
Author: Daniel Fraubaum | headsinthecloud.blog
Version: 1.0.0
Date: 2025-10-27
Description: Intune remediation script. Disables NetBIOS (TcpipNetbiosOptions = 2)
             on all active, physical, IP-enabled network adapters using the
             SetTcpipNetbios CIM method. Exits 0 if successful or nothing to do,
             otherwise exits 1.
#>
####################################################################
# Parameters
####################################################################
# Set this to $true if you also want to stamp the registry for persistence:
$EnableRegistryPersistence = $false

####################################################################
# Helper Functions
####################################################################
function Get-ActivePhysicalNics {
    try {
        return Get-NetAdapter |
            Where-Object {
                $_.Status -eq 'Up' -and
                $_.ConnectorPresent -eq $true -and
                ($_.HardwareInterface -eq $true -or $_.Virtual -ne $true)
            }
    } catch {
        return @()
    }
}

function Get-IpEnabledCimConfigs {
    try {
        return Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE"
    } catch {
        return @()
    }
}

function Match-NicToCimByMac {
    param(
        [Parameter(Mandatory = $true)]$Nic,
        [Parameter(Mandatory = $true)]$CimList
    )
    if (-not $Nic -or -not $CimList) { return $null }
    try {
        return $CimList |
            Where-Object { $_.MACAddress -and ($_.MACAddress -eq $Nic.MacAddress) } |
            Select-Object -First 1
    } catch {
        return $null
    }
}

function Get-NetbiosOption {
    param([Parameter(Mandatory = $true)]$Cim)
    try { return [int]$Cim.TcpipNetbiosOptions } catch { return $null }
}

function Describe-NetbiosOption {
    param([int]$State)
    switch ($State) {
        0 { 'EnableNetbiosViaDhcp' }
        1 { 'EnableNetbios' }
        2 { 'DisableNetbios' }
        default { 'Unknown' }
    }
}

function Disable-Netbios {
    <#
    .SYNOPSIS
        Applies SetTcpipNetbios = 2 and verifies the result.
    #>
    param([Parameter(Mandatory = $true)]$Cim)
    try {
        $res = Invoke-CimMethod -InputObject $Cim -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = 2 }
        if ($null -ne $res -and $res.PSObject.Properties.Match('ReturnValue').Count -gt 0) {
            if ($res.ReturnValue -ne 0) { return $false }
        }
        Start-Sleep -Milliseconds 150
        return ((Get-NetbiosOption -Cim $Cim) -eq 2)
    } catch {
        return $false
    }
}

# Optional registry helpers for persistence (NetBT Interfaces\Tcpip_{SettingID})
function Ensure-RegistryKey {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        try { New-Item -Path $Path -Force | Out-Null } catch {}
    }
}
function Set-RegistryDword {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int]$Value
    )
    Ensure-RegistryKey -Path $Path
    try {
        New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType DWord -Value $Value -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

####################################################################
# Remediation Logic
####################################################################
$modified = @()
$skipped  = @()
$errors   = @()

$adapters = Get-ActivePhysicalNics
if (-not $adapters -or $adapters.Count -eq 0) {
    # Nothing to change
    Exit 0
}

$cimAll = Get-IpEnabledCimConfigs

foreach ($nic in $adapters) {
    $cim = Match-NicToCimByMac -Nic $nic -CimList $cimAll
    if (-not $cim) {
        $skipped += "No IP-enabled CIM mapping for '$($nic.InterfaceDescription)' [$($nic.MacAddress)]"
        continue
    }

    $stateBefore = Get-NetbiosOption -Cim $cim
    if ($stateBefore -eq 2) {
        $skipped += "Already disabled on '$($nic.InterfaceDescription)' [$($nic.MacAddress)]"
        continue
    }

    if (Disable-Netbios -Cim $cim) {
        # Optional registry persistence (disabled by default)
        if ($EnableRegistryPersistence -and $cim.SettingID) {
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces\Tcpip_$($cim.SettingID)"
            if (-not (Set-RegistryDword -Path $regPath -Name 'NetbiosOptions' -Value 2)) {
                $errors += "Failed to set registry NetbiosOptions at $regPath"
            }
        }

        Start-Sleep -Milliseconds 150
        $stateAfter = Get-NetbiosOption -Cim $cim
        if ($stateAfter -eq 2) {
            $modified += "Disabled NetBIOS on '$($nic.InterfaceDescription)' [$($nic.MacAddress)] (was: $stateBefore/$((Describe-NetbiosOption $stateBefore)))"
        } else {
            $errors += "Post-verify failed on '$($nic.InterfaceDescription)' [$($nic.MacAddress)] (now: $stateAfter/$((Describe-NetbiosOption $stateAfter)))"
        }
    } else {
        $stateNow = Get-NetbiosOption -Cim $cim
        $errors += "Failed to disable NetBIOS on '$($nic.InterfaceDescription)' [$($nic.MacAddress)] (current: $stateNow/$((Describe-NetbiosOption $stateNow)))"
    }
}

# Output (minimal—adjust as needed)
$skipped  | ForEach-Object { Write-Output "[Remediate] $_" }
$modified | ForEach-Object { Write-Output "[Success] $_" }
$errors   | ForEach-Object { Write-Output "[Error] $_" }

if ($errors.Count -gt 0) { Exit 1 } else { Exit 0 }
# end
