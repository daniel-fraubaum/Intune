<#
    Script:      Remediate_DisableNetBIOS.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.1
    Date:        2026-11-26
    Description: Disables NetBIOS over TCP/IP (TcpipNetbiosOptions = 2) on all active, physical
                 network adapters with IP enabled, using the SetTcpipNetbios method of
                 Win32_NetworkAdapterConfiguration, and verifies the result.
#>

# ==== Parameters ====
# Must match the value in Detect_DisableNetBIOS.ps1. 0 = from DHCP, 1 = enabled, 2 = disabled
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
        Write-Output "Nothing to do: no active physical adapter with IP enabled"
        exit 0
    }

    $Failed = 0
    foreach ($Config in $Configs) {
        $Name   = $Config.Description
        $Before = [int]$Config.TcpipNetbiosOptions
        if ($Before -eq $DesiredOption) {
            Write-Output "OK:    $Name"
            continue
        }

        # Step 2: Disable NetBIOS (ReturnValue 0 = done, 1 = done, restart required)
        $Result = Invoke-CimMethod -InputObject $Config -MethodName SetTcpipNetbios -Arguments @{ TcpipNetbiosOptions = [uint32]$DesiredOption } -ErrorAction Stop
        if ($Result.ReturnValue -notin 0, 1) {
            Write-Output "Error: $Name, SetTcpipNetbios returned $($Result.ReturnValue)"
            $Failed++
            continue
        }

        # Step 3: Read the adapter again, the object above still holds the old value
        $After = [int](Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "Index = $($Config.Index)" -ErrorAction Stop).TcpipNetbiosOptions
        if ($After -eq $DesiredOption) {
            Write-Output "Set:   $Name, NetBIOS disabled (was $Before)"
        }
        else {
            Write-Output "Error: $Name, TcpipNetbiosOptions is still $After"
            $Failed++
        }
    }

    if ($Failed -gt 0) {
        Write-Error "Remediation failed on $Failed adapter(s)"
        exit 1
    }
    Write-Output "Remediated: NetBIOS disabled on $($Configs.Count) adapter(s)"
    exit 0
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
