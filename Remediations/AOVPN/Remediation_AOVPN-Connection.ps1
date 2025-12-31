
<#
Script: Remediate AOVPN Profile
Author: Daniel Fraubaum | headsinthecloud.blog
Version: 1.0.0
Date: 2025-12-31
Description: Intune Remediation Script.
             Removes and re-creates the AOVPN profile using the MDM Bridge (VPNv2 CSP)
             with the exact ProfileXML provided below. No server normalization used.
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
# Replace the XML below to deploy a different AOVPN configuration.
# Keep namespaces and EAP block formatting intact.
# Placeholders used:
#   - VPN Server FQDN: aovpn.example.com
#   - DNS Suffix / Domain Name: ad.example.com
#   - DNS Servers: 10.0.0.10,10.0.0.11
#   - CA Hash placeholder: AA BB CC DD ... (Replace with your real CA hash values)
#   - Pseudo routes: 10.0.0.0/24, 10.0.1.0/24, 203.0.113.10/32, 198.51.100.25/32, 192.0.2.50/32
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
# Remediation Logic
# ==============================
try {
    # Final XML straight, no server normalization
    [xml]$Xml = $DesiredXml
    $FinalXml = $Xml.OuterXml

    # MDM Bridge details
    $ns  = 'root\cimv2\mdm\dmmap'
    $cls = 'MDM_VPNv2_01'

    # Remove existing instance if present
    $existing = Get-CimInstance -Namespace $ns -ClassName $cls -ErrorAction SilentlyContinue |
                Where-Object { $_.ParentID -eq './Vendor/MSFT/VPNv2' -and $_.InstanceID -eq $ProfileName }
    if ($existing) {
        Remove-CimInstance -CimInstance $existing -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
    }

    # Create new instance with ProfileXML
    $newProps = @{
        ParentID   = './Vendor/MSFT/VPNv2'
        InstanceID = $ProfileName
        ProfileXML = $FinalXml
    }

    $null = New-CimInstance -Namespace $ns -ClassName $cls -Property $newProps -ErrorAction Stop

    # Basic validation
    $check = Get-CimInstance -Namespace $ns -ClassName $cls -ErrorAction SilentlyContinue |
             Where-Object { $_.ParentID -eq './Vendor/MSFT/VPNv2' -and $_.InstanceID -eq $ProfileName }

    if ($check -and -not [string]::IsNullOrWhiteSpace($check.ProfileXML)) {
        Write-Output "Remediation applied: AOVPN profile '$ProfileName' deployed."
    }
    else {
        throw "Validation failed after deployment."
    }
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
}
