<#
Script: Disable NetBIOS - Detection Script
Author: Daniel Fraubaum | headsinthecloud.blog
Version: 1.0.0
Date: 2025-10-27
Description: Intune remediation detection script. Checks whether NetBIOS
             (TcpipNetbiosOptions) is disabled (value = 2) on all active,
             physical, IP-enabled network adapters. Exits 0 if compliant,
             otherwise exits 1 to trigger remediation.
#>
####################################################################
# Parameters
####################################################################
# No static parameters required; discovery is dynamic.

####################################################################
# Helper Functions
####################################################################
function Get-ActivePhysicalNics {
    <#
    .SYNOPSIS
        Returns active, physical NICs (no virtuals), with a link present.
    #>
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
    <#
    .SYNOPSIS
        Returns IP-enabled Win32_NetworkAdapterConfiguration instances.
    #>
    try {
        return Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE"
    } catch {
        return @()
    }
}

function Match-NicToCimByMac {
    <#
    .SYNOPSIS
        Matches a NetAdapter object to a Win32_NetworkAdapterConfiguration object using MAC.
    #>
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
    <#
    .SYNOPSIS
        Reads TcpipNetbiosOptions from a Win32_NetworkAdapterConfiguration object.
    #>
    param([Parameter(Mandatory = $true)]$Cim)
    try { return [int]$Cim.TcpipNetbiosOptions } catch { return $null }
}

function Describe-NetbiosOption {
    <#
    .SYNOPSIS
        Returns a human-readable description of the NetBIOS option.
    #>
    param([int]$State)
    switch ($State) {
        0 { 'EnableNetbiosViaDhcp' }
        1 { 'EnableNetbios' }
        2 { 'DisableNetbios' }
        default { 'Unknown' }
    }
}

####################################################################
# Detection Logic
####################################################################
$issues = @()

# Discover adapters and their CIM configs
$adapters = Get-ActivePhysicalNics
if (-not $adapters -or $adapters.Count -eq 0) {
    # No active physical adapters -> nothing to enforce
    Exit 0
}

$cimAll = Get-IpEnabledCimConfigs
foreach ($nic in $adapters) {
    $cim = Match-NicToCimByMac -Nic $nic -CimList $cimAll
    if (-not $cim) {
        $issues += "No IP-enabled CIM mapping for '$($nic.InterfaceDescription)' [$($nic.MacAddress)]"
        continue
    }

    $state = Get-NetbiosOption -Cim $cim
    if ($state -ne 2) {
        $issues += "NetBIOS not disabled on '$($nic.InterfaceDescription)' [$($nic.MacAddress)] :: State=$state ($((Describe-NetbiosOption $state)))"
    }
}

if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Output "[Detect] $_" }
    Exit 1
} else {
    # Silent success (like your sample), or uncomment for a line of output:
    # Write-Output "[Detect] All active physical adapters have NetBIOS disabled (2)."
    Exit 0
}
# end
