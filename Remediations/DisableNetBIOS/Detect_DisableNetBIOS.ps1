<#
    Script:      Detect_DisableNetBIOS.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Detects whether NetBIOS over TCP/IP is disabled (TcpipNetbiosOptions = 2) on all
                 active, physical network adapters with IP enabled.
                 Exit 0 = compliant, exit 1 = remediation required.
#>

# ==== Parameters ====
# Must match the value in Remediate_DisableNetBIOS.ps1. 0 = from DHCP, 1 = enabled, 2 = disabled
$DesiredOption = 2

# ==== Functions ====
function Get-TargetAdapterConfigs {
    # Active, physical adapters with a link (no virtual adapters)
    $Adapters = @(Get-NetAdapter -ErrorAction Stop | Where-Object {
        $_.Status -eq "Up" -and $_.ConnectorPresent -and ($_.HardwareInterface -or -not $_.Virtual)
    })
    if ($Adapters.Count -eq 0) { return @() }

    # Match the IP configuration by interface index, the MAC address format differs between the two APIs
    $Indexes = @($Adapters | ForEach-Object { $_.InterfaceIndex })
    @(Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE" -ErrorAction Stop |
        Where-Object { $Indexes -contains $_.InterfaceIndex })
}

# ==== Logic ====
try {
    # Step 1: Find the adapters in scope
    $Configs = @(Get-TargetAdapterConfigs)
    if ($Configs.Count -eq 0) {
        Write-Output "Compliant: no active physical adapter with IP enabled"
        exit 0
    }

    # Step 2: Check the NetBIOS setting of every adapter
    $Wrong = @($Configs | Where-Object { [int]$_.TcpipNetbiosOptions -ne $DesiredOption })
    if ($Wrong.Count -gt 0) {
        $List = ($Wrong | ForEach-Object { "$($_.Description) (TcpipNetbiosOptions=$($_.TcpipNetbiosOptions))" }) -join ", "
        Write-Output "Not compliant: NetBIOS not disabled on $List"
        exit 1
    }

    Write-Output "Compliant: NetBIOS disabled on $($Configs.Count) adapter(s)"
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
