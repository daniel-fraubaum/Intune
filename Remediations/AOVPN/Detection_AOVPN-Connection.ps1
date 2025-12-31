<#
Script: Detect AOVPN Profile
Author: Daniel Fraubaum | headsinthecloud.blog
Version: 1.0.0
Date: 2025-12-31
Description: Intune Detection Script.
             Verifies that the Always On VPN profile exists and matches the expected configuration.
             Compares key profile properties, routes, domain info, and an EAP block hash.
             Exit code 0  -> compliant
             Exit code 1  -> remediation required
#>

# ==============================
# EDIT HERE: COMMON SETTINGS
# ==============================
# The InstanceID under ./Vendor/MSFT/VPNv2 will be used as the profile's name.
# Change this if you want a different profile name.
$ProfileName = "ConnectionName-AOVPN-User"   # <<< EDIT HERE if needed

# ==============================
# EDIT HERE: YOUR DESIRED PROFILE XML
# ==============================
# Replace the XML below if you want to deploy a different AOVPN configuration.
# Keep namespaces and EAP block formatting intact to avoid unexpected changes to the EAP hash.
# Placeholders used:
#   - VPN Server FQDN: aovpn.example.com
#   - DNS Suffix / Domain Name: ad.example.com
#   - DNS Servers: 10.0.0.10,10.0.0.11
#   - CA Hash placeholder: AA BB CC DD ... (Replace with your real CA hash values)
$DesiredXml = @'
<VPNProfile>
   <AlwaysOn>true</AlwaysOn>
   <DnsSuffix>ad.example.com</DnsSuffix>

   <DisableAdvancedOptionsEditButton>true</DisableAdvancedOptionsEditButton>
   <DisableDisconnectButton>true</DisableDisconnectButton>

   <NativeProfile>
      <Servers>aovpn.example.com</Servers>

      <!-- Routing policy -->
      <RoutingPolicyType>SplitTunnel</RoutingPolicyType>

      <!-- Protocol selection -->
      <NativeProtocolType>Automatic</NativeProtocolType>

      <Authentication>
         <UserMethod>EAP</UserMethod>
         <MachineMethod>EAP</MachineMethod>
         <Eap>
            <Configuration>
               <EapHostConfig xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
                  <EapMethod>
                     <Type xmlns="http://www.microsoft.com/provisioning/EapCommon">25</Type>
                     <VendorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorId>
                     <VendorType xmlns="http://www.microsoft.com/provisioning/EapCommon">0</VendorType>
                     <AuthorId xmlns="http://www.microsoft.com/provisioning/EapCommon">0</AuthorId>
                  </EapMethod>
                  <Config xmlns="http://www.microsoft.com/provisioning/EapHostConfig">
                     <Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1">
                        <Type>25</Type>
                        <EapType xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV1">
                           <ServerValidation>
                              <DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation>
                              <ServerNames>aovpn.example.com</ServerNames>
                           </ServerValidation>
                           <FastReconnect>true</FastReconnect>
                           <InnerEapOptional>false</InnerEapOptional>
                           <Eap xmlns="http://www.microsoft.com/provisioning/BaseEapConnectionPropertiesV1">
                              <Type>13</Type>
                              <EapType xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV1">
                                 <CredentialsSource>
                                    <CertificateStore>
                                       <SimpleCertSelection>true</SimpleCertSelection>
                                    </CertificateStore>
                                 </CredentialsSource>
                                 <ServerValidation>
                                    <DisableUserPromptForServerValidation>false</DisableUserPromptForServerValidation>
                                    <ServerNames></ServerNames>
                                 </ServerValidation>
                                 <DifferentUsername>false</DifferentUsername>
                                 <PerformServerValidation xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</PerformServerValidation>
                                 <AcceptServerName xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">false</AcceptServerName>
                                 <TLSExtensions xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV2">
                                    <FilteringInfo xmlns="http://www.microsoft.com/provisioning/EapTlsConnectionPropertiesV3">
                                       <CAHashList Enabled="true">
                                          <IssuerHash>AA BB CC DD EE FF 00 11 22 33 44 55 66 77 88 99 AA BB CC DD</IssuerHash>
                                       </CAHashList> 
                                    </FilteringInfo>
                                 </TLSExtensions>
                              </EapType>
                           </Eap>
                           <EnableQuarantineChecks>false</EnableQuarantineChecks>
                           <RequireCryptoBinding>false</RequireCryptoBinding>
                           <PeapExtensions>
                              <PerformServerValidation xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV2">true</PerformServerValidation>
                              <AcceptServerName xmlns="http://www.microsoft.com/provisioning/MsPeapConnectionPropertiesV2">false</AcceptServerName>
                           </PeapExtensions>
                        </EapType>
                     </Eap>
                  </Config>
               </EapHostConfig>
            </Configuration>
         </Eap>
      </Authentication>

      <!-- Recommended optional setting -->
      <DisableClassBasedDefaultRoute>true</DisableClassBasedDefaultRoute>
   </NativeProfile>

   <!-- Routes required when DisableClassBasedDefaultRoute is true -->
   <Route>
      <Address>10.0.0.0</Address>
      <PrefixSize>24</PrefixSize>
   </Route>
   <Route>
      <Address>10.0.1.0</Address>
      <PrefixSize>24</PrefixSize>
   </Route>
   <Route>
      <Address>203.0.113.10</Address>
      <PrefixSize>32</PrefixSize>
   </Route>
   <Route>
      <Address>198.51.100.25</Address>
      <PrefixSize>32</PrefixSize>
   </Route>
   <Route>
      <Address>192.0.2.50</Address>
      <PrefixSize>32</PrefixSize>
   </Route>

   <!-- Domain name information if VPN server-side DNS cannot resolve AD hosts -->
   <DomainNameInformation>
      <DomainName>ad.example.com</DomainName>
      <DnsServers>10.0.0.10,10.0.0.11</DnsServers>
   </DomainNameInformation>

   <NetworkOutageTime>0</NetworkOutageTime>
   <IPv4InterfaceMetric>3</IPv4InterfaceMetric>
   <IPv6InterfaceMetric>3</IPv6InterfaceMetric>
   <UseRasCredentials>false</UseRasCredentials>
   <DataEncryption>Max</DataEncryption>
   <DisableIKEv2Fragmentation>false</DisableIKEv2Fragmentation>
</VPNProfile>
'@

# ==============================
# Helper Functions
# ==============================
function ConvertTo-Sha256 {
    param([Parameter(Mandatory)][string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha   = [System.Security.Cryptography.SHA256]::Create()
    ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Get-InstalledProfileXml {
    $ns = 'root\cimv2\mdm\dmmap'
    $cls = 'MDM_VPNv2_01'
    $item = Get-CimInstance -Namespace $ns -ClassName $cls -ErrorAction SilentlyContinue |
            Where-Object { $_.ParentID -eq './Vendor/MSFT/VPNv2' -and $_.InstanceID -eq $ProfileName }
    return $item.ProfileXML
}

function Extract-ConfigDigest {
    param([xml]$Xml)

    $vpn = $Xml.VPNProfile
    $np  = $vpn.NativeProfile

    $map = [ordered]@{
        AlwaysOn                          = ($vpn.AlwaysOn  | Out-String).Trim().ToLower()
        DnsSuffix                         = ($vpn.DnsSuffix | Out-String).Trim().ToLower()
        
        DisableAdvancedOptionsEditButton  = ($vpn.DisableAdvancedOptionsEditButton | Out-String).Trim().ToLower()
        DisableDisconnectButton           = ($vpn.DisableDisconnectButton          | Out-String).Trim().ToLower()
        
        RoutingPolicyType                 = ($np.RoutingPolicyType | Out-String).Trim()
        NativeProtocolType                = ($np.NativeProtocolType | Out-String).Trim()
        Servers                           = ($np.Servers | Out-String).Trim()
        
        DisableClassBasedDefaultRoute     = ($np.DisableClassBasedDefaultRoute | Out-String).Trim().ToLower()
        
        NetworkOutageTime                 = ($vpn.NetworkOutageTime | Out-String).Trim()
        IPv4InterfaceMetric               = ($vpn.IPv4InterfaceMetric | Out-String).Trim()
        IPv6InterfaceMetric               = ($vpn.IPv6InterfaceMetric | Out-String).Trim()
        UseRasCredentials                 = ($vpn.UseRasCredentials | Out-String).Trim().ToLower()
        DataEncryption                    = ($vpn.DataEncryption | Out-String).Trim()
        DisableIKEv2Fragmentation         = ($vpn.DisableIKEv2Fragmentation | Out-String).Trim().ToLower()
    }

    # Routes exact set, sorted for stable digest
    $routes = @()
    foreach ($r in $vpn.Route) {
        $addr = ($r.Address | Out-String).Trim()
        $pre  = ($r.PrefixSize | Out-String).Trim()
        if ($addr -and $pre) { $routes += "$addr/$pre" }
    }
    $map.Routes = ($routes | Sort-Object) -join ';'

    # DomainNameInformation exact values, normalized only for whitespace
    $dnis = @()
    foreach ($d in $vpn.DomainNameInformation) {
        $dn  = ($d.DomainName | Out-String).Trim()
        $dns = ($d.DnsServers  | Out-String).Trim()
        $dnslist = ($dns -split '[,; ]+' | Where-Object { $_ }) -join ','
        if ($dn) { $dnis += "$dn|$dnslist" }
    }
    $map.DomainNameInformation = ($dnis | Sort-Object) -join ';'

    # EAP block hash
    $eapNode = $Xml.SelectSingleNode("//*[local-name()='EapHostConfig']")
    $map.EapHash = if ($eapNode) { ConvertTo-Sha256 -Text ($eapNode.OuterXml -replace '\s+', ' ') } else { '' }

    $json = $map | ConvertTo-Json -Depth 10
    return (ConvertTo-Sha256 -Text $json)
}

# ==============================
# Detection Logic
# ==============================
try {
    # Desired digest straight from your XML
    [xml]$Desired = $DesiredXml
    $DesiredDigest = Extract-ConfigDigest -Xml $Desired

    # Retrieve installed XML from the MDM Bridge
    $installedXmlString = Get-InstalledProfileXml
    if ([string]::IsNullOrWhiteSpace($installedXmlString)) {
        Write-Output "AOVPN profile '$ProfileName' is missing."
        exit 1
    }

    [xml]$Installed = $installedXmlString
    $InstalledDigest = Extract-ConfigDigest -Xml $Installed

    if ($InstalledDigest -eq $DesiredDigest) {
        Write-Output "AOVPN profile '$ProfileName' is compliant."
        exit 0
    } else {
        Write-Output "AOVPN profile '$ProfileName' exists but is not compliant."
        exit 1
    }
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
