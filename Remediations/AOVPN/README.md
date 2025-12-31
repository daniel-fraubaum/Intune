
# Intune Remediation: Always On VPN (AOVPN) Profile Deployment

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.0.0**  
Last update: **2025-12-31**

This repository contains an **Intune Remediation** pair to deploy and continuously enforce a Windows **Always On VPN** profile using the **MDM Bridge** and the **VPNv2 CSP**.  
The solution is **idempotent**. The detection script verifies that the profile on the device matches your desired configuration. The remediation script removes and re‑creates the profile only when differences are detected.

> Important  
> These scripts use **placeholders**. Replace them with your values before production. See the section **Placeholders to replace**.

---

## What this package does

- Creates or updates an AOVPN profile under `./Vendor/MSFT/VPNv2/<ProfileName>`  
- Validates the installed profile against your **desired ProfileXML**  
- Reapplies the profile when drift is detected  
- Runs as **SYSTEM** in **64‑bit PowerShell** through Intune Remediations  
- Avoids the common pitfall of name‑only checks by hashing key fields and the **EAP block**

---

## Files

- `Detect-AOVPN-Profile.ps1`  
  Detection script. Returns exit code `0` if compliant and `1` if remediation is required.

- `Remediate-AOVPN-Profile.ps1`  
  Remediation script. Removes the existing VPNv2 instance and recreates it with your ProfileXML.

Both scripts contain clear **EDIT HERE** markers to guide you through changes.

---

## Placeholders to replace

In **both** scripts, search the **EDIT HERE** blocks and adjust the following:

- `"$ProfileName"`  
  The name used as the **InstanceID** under `./Vendor/MSFT/VPNv2`. Example: `ConnectionName-AOVPN-User`.

- `$DesiredXml`  
  Replace the entire XML block with your own ProfileXML or adjust the placeholders inside:
  - VPN Server FQDN: `aovpn.example.com`
  - DNS Suffix and Domain Name: `ad.example.com`
  - DNS Servers: `10.0.0.10,10.0.0.11`
  - CA Hash placeholder in the EAP block:
    ```
    AA BB CC DD EE FF 00 11 22 33 44 55 66 77 88 99 AA BB CC DD
    ```
  - Pseudo routes used for sample only:
    - `10.0.0.0/24`
    - `10.0.1.0/24`
    - `203.0.113.10/32`
    - `198.51.100.25/32`
    - `192.0.2.50/32`

> Note  
> The route examples use RFC 5737 documentation ranges and private ranges for illustration. Replace them with your environment subnets and hosts.

---

## How detection works

The detection script:
- Pulls the installed XML via the **MDM Bridge** class `MDM_VPNv2_01`  
- Extracts key fields into a canonical map:
  - AlwaysOn, DnsSuffix, DisableAdvancedOptionsEditButton, DisableDisconnectButton
  - NativeProfile fields: Servers, RoutingPolicyType, NativeProtocolType, DisableClassBasedDefaultRoute
  - Routes list (sorted), DomainNameInformation list (sorted)
  - Windows 11 settings: NetworkOutageTime, IPv4InterfaceMetric, IPv6InterfaceMetric, UseRasCredentials, DataEncryption, DisableIKEv2Fragmentation
  - A **SHA‑256** hash of the `EapHostConfig` block
- Computes a digest of the desired XML and the installed XML and compares the two  
- Returns `0` if they match, `1` if they differ, or `1` if the profile is missing

This ensures that any meaningful change to your ProfileXML triggers remediation.

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create package**

2. **Basics**  
   - Name: `AOVPN - ConnectionName-AOVPN-User`  
   - Description: Deploy and enforce AOVPN profile via MDM Bridge

3. **Detection script**  
   - Upload `Detect-AOVPN-Profile.ps1`

4. **Remediation script**  
   - Upload `Remediate-AOVPN-Profile.ps1`

5. **Settings**  
   - Run this script using the logged-on credentials: **No**  
   - Run script in 64‑bit PowerShell: **Yes**  
   - Signature check: as per your org policy

6. **Assignments**  
   - Assign to a device group that represents your pilot or production scope

7. **Schedule**  
   - Start with **Hourly** during rollout  
   - Move to **Daily** in steady state

8. **Monitor**  
   - Review status in the Remediation package dashboard  
   - Check device script outputs for detection and remediation logs

---

## Testing checklist

- Target a single test device or a small pilot group  
- Verify the profile appears under **Settings → Network & Internet → VPN**  
- Confirm the connection properties reflect your ProfileXML  
- Review the device log in the remediation package for status messages  
- Test actual connectivity and authentication

---

## Common customizations

- **Profile name change**  
  Change `$ProfileName` in both scripts to roll out a parallel profile version.  
  Example: `ConnectionName-AOVPN-User-v2`

- **Switching protocols**  
  In the XML, set `<NativeProtocolType>` to `IKEv2` or `Sstp` based on your design.

- **EAP configuration**  
  Replace the EAP block with your exported EAP XML. Keep namespaces intact.  
  Small formatting changes can alter the EAP hash and will trigger remediation. This is expected for planned changes.

- **Routes**  
  Add or remove `<Route>` blocks in the XML. Detection sorts and compares the set, so any change will be detected.

- **DomainNameInformation**  
  Adjust `<DomainName>` and `<DnsServers>` as needed. The detection normalizes basic whitespace.

---

## Troubleshooting

- **Remediation keeps applying**  
  - Verify your desired XML is exactly what you want.  
  - Check that EAP namespaces and structure are intact.  
  - Confirm you updated the XML in **both** scripts.

- **Profile does not appear**  
  - Ensure the remediation runs as SYSTEM in 64‑bit PowerShell.  
  - Check for typos in `$ProfileName`.  
  - Review the remediation output in Intune for errors.

- **EAP or certificate errors**  
  - Validate the CA hash and trust chain on the client.  
  - Confirm the user or device has a suitable certificate if using EAP‑TLS.

---

## Security notes

- Run in SYSTEM context.  
- Consider code signing the scripts and enabling signature validation.  
- Treat the ProfileXML as configuration, not secrets. Handle certificates and private keys through your PKI and Intune profiles.

---

## Versioning

- Update the header `Version` and `Date` fields in both scripts when you make changes.  
- Consider tagging GitHub releases that map to specific XML revisions.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non‑production environment before broad deployment.

---

## License

Recommend **MIT License** for community reuse.

---

## Quick start

1. Open both scripts  
2. Replace placeholders inside the **EDIT HERE** sections  
3. Import into Intune Remediations  
4. Assign to a test group and monitor results  
5. Expand to production when validated
