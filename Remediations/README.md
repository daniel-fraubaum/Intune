# Intune Remediations

Detection and remediation script pairs for **Intune Remediations** (Devices → Scripts and remediations → Remediations).  
Unless noted otherwise, run them as **SYSTEM** in **64-bit PowerShell**.

| Folder | Description |
| --- | --- |
| [CVE-2013-3900](./CVE-2013-3900) | Enables the WinVerifyTrust signature validation fix (`EnableCertPaddingCheck`) for CVE-2013-3900 |
| [DisableNetBIOS](./DisableNetBIOS) | Disables NetBIOS over TCP/IP on all active, physical network adapters |
| [FixUnquotedServicePaths](./FixUnquotedServicePaths) | Finds and quotes unquoted service paths and uninstall strings |
| [RebootReminder](./RebootReminder) | Shows a modern reboot popup with countdown after X days uptime and enforces the reboot |
| [SecureBootCertUpdate](./SecureBootCertUpdate) | Opts devices in to the Microsoft managed Secure Boot certificate update and detects the Windows UEFI CA 2023 |
| [SmartCardRemovalPolicyService](./SmartCardRemovalPolicyService) | Sets the Smart Card Removal Policy service to Automatic (Delayed Start) and starts it |

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
