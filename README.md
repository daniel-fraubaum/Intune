# 🧰 Intune

Scripts and app packages for **Microsoft Intune** from real-world projects, shared on [headsinthecloud.blog](https://headsinthecloud.blog). Every package has its own README with what it does, the Intune settings, how to test it and what to watch out for.

## 📂 Contents

| Folder | Content |
|---|---|
| [🩹 Remediations](./Remediations) | Detection and remediation script pairs for **Intune Remediations** |
| [📦 Win32Apps](./Win32Apps) | **Win32 app** packages: scripts and README, packaged with IntuneWinAppUtil |

## 🩹 Remediations

| Remediation | Description |
|---|---|
| [🛡️ AdobeSecureScoreSettings](./Remediations/AdobeSecureScoreSettings) | Adobe Acrobat and Reader DC lockdown settings for Secure Score: Flash off, JavaScript off, Protected Mode on |
| [🔎 CompanyPortalSearchShortcut](./Remediations/CompanyPortalSearchShortcut) | English-named Company Portal shortcut, so Start search finds "Intune" and "Company Portal" on non-English clients |
| [🌐 DisableNetBIOS](./Remediations/DisableNetBIOS) | Disables NetBIOS over TCP/IP on all active, physical network adapters with IP enabled |
| [⭐ EdgeManagedFavorites](./Remediations/EdgeManagedFavorites) | Merges the Edge managed favorites of several remediations into one favorites tree, per device (HKLM) or per user (HKCU) |
| [🗑️ FixDesktopDeletionRight](./Remediations/FixDesktopDeletionRight) | Lets standard users delete shortcuts that installers put on the Public Desktop |
| [🔒 FixUnquotedServicePaths](./Remediations/FixUnquotedServicePaths) | Puts quotes around unquoted service paths with spaces |
| [🔄 RebootReminder](./Remediations/RebootReminder) | Modern reboot popup with countdown after X days uptime, enforces the reboot |
| [🔑 SecureBootCertUpdate](./Remediations/SecureBootCertUpdate) | Opts in to the Microsoft managed Secure Boot certificate update and checks for the Windows UEFI CA 2023 |
| [🏷️ ShowFileExtensions](./Remediations/ShowFileExtensions) | Shows file extensions for known file types in File Explorer |
| [👁️ ShowHiddenFiles](./Remediations/ShowHiddenFiles) | Shows hidden files and folders in File Explorer |
| [💳 SmartCardRemovalPolicyService](./Remediations/SmartCardRemovalPolicyService) | Sets the Smart Card Removal Policy service to Automatic (Delayed Start) and starts it |

More details and screenshots in the [Remediations overview](./Remediations/README.md).

## 📦 Win32 apps

| App | Description |
|---|---|
| [🌍 Set-DeviceLanguage](./Win32Apps/Set-DeviceLanguage) | Switches the Windows 11 display language, regional format and country/region, for Autopilot and the Company Portal, with a restart reminder popup |

## 🚀 How to use

1. Open the folder of the package and read its README.
2. Adjust the **Parameters** block at the top of the scripts, for example registry paths, company name and texts. Values that must match in detection and remediation are marked in the README.
3. Create the remediation or Win32 app in the Intune admin center with the settings from the README.
4. Test on a single device or a pilot group before you assign it broadly.

To download a single package, open its folder on GitHub and download the files, or download the whole repository with **Code > Download ZIP**.

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
