# 🌍 Set-DeviceLanguage

Switch the Windows 11 display language, regional format and country/region with a single Intune Win32 app. One package covers both scenarios: set the language once during Autopilot, and let users change it themselves from the Company Portal with one click.

No Store Local Experience Packs, no Administrative Template policies that lock users in, no message boxes with a 24 hour shutdown timer. The script installs the language with `Install-Language`, applies it to the system, the Welcome screen, new profiles and the signed-in user, and hands the restart over to Intune.

## ✨ Features

- Installs the language pack and language features on demand (skips the download if the language is already there)
- Sets display language, preferred language list, regional format, country/region and system locale
- Copies the settings to the Welcome screen and to new user profiles
- Applies the settings to the signed-in user through a one-time scheduled task in user context
- Keeps existing languages and keyboard layouts of the user, the new language is only moved to the top
- Works with no user signed in (Autopilot ESP device phase) and with a signed-in user (Company Portal)
- Two separate detection markers, so the Autopilot app never overrides the user's later choice
- Checks all prerequisites before changing anything
- Logs to the Intune Management Extension log folder, so "Collect diagnostics" picks it up
- Returns `3010`, the restart is handled by Intune

## ⚙️ How it works

| Step | Context | What happens |
|---|---|---|
| 1 | SYSTEM | Prerequisite checks (64-bit, admin, Windows 11 22H2+, module, valid tags) |
| 2 | SYSTEM | `Install-Language` if the language is not installed yet |
| 3 | SYSTEM | Display language, language list, regional format, country/region and system locale for the SYSTEM account |
| 4 | SYSTEM | `Copy-UserInternationalSettingsToSystem` to the Welcome screen and new user profiles |
| 5 | User | For every signed-in user: one-time scheduled task that sets language list, display language, regional format and country/region |
| 6 | SYSTEM | Detection marker in the registry |
| 7 | Intune | Exit code `3010`, restart with the Intune restart grace period |

If nobody is signed in, step 5 is skipped. The first user who signs in after the restart gets the settings from step 4.

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows 11 22H2 (build 22621) or later |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Module | `LanguagePackManagement` (built into Windows 11) |
| Context | SYSTEM (Win32 app install behavior: System) |
| Network | Access to Windows Update / Features on Demand for the language download |

## 🔧 Configuration

Before packaging, adjust the configuration block at the top of the script. These values are the same for every app and are not passed on the command line.

| Variable | Default | Description |
|---|---|---|
| `$MarkerKeyPath` | `HKLM:\SOFTWARE\CompanyName\DeviceLanguage` | Registry key for the detection markers. Set this to your own company key. |
| `$MarkerValueName` | `Language` | Marker for the Company Portal apps (last selected language) |
| `$InitialMarkerValueName` | `InitialLanguage` | Marker for the Autopilot app (only written with `-InitialSetup`) |
| `$WorkingFolder` | `%ProgramData%\DeviceLanguage` | Temporary folder for the user script, cleaned up afterwards |
| `$LogFile` | `%ProgramData%\Microsoft\IntuneManagementExtension\Logs\Set-DeviceLanguage.log` | Log file |
| `$UserTaskTimeoutSeconds` | `300` | Maximum wait time for the user part |

## 🎛️ Parameters

| Parameter | Required | Example | Description |
|---|---|---|---|
| `-Language` | Yes | `en-US` | Display language to install and apply |
| `-Culture` | No | `de-AT` | Regional format for date, time, numbers and currency. Defaults to `-Language` |
| `-GeoId` | No | `14` | Country or region. `0` or not set leaves it unchanged |
| `-InitialSetup` | No | | Use for the Autopilot app. Writes the `InitialLanguage` marker in addition to `Language` |

### Language, Culture and GeoId explained

These three are separate settings in Windows and it pays off to keep them separate:

| Setting | Windows name | Controls |
|---|---|---|
| `-Language` | Windows display language | Menus, dialogs, Settings app, Company Portal |
| `-Culture` | Regional format | Date and time format, decimal separator, currency, first day of the week |
| `-GeoId` | Country or region | Store content, regional content like news and weather, some apps |

A user in Vienna who prefers English menus still wants `18.11.2026`, a decimal comma and Euro. That is `-Language "en-US" -Culture "de-AT" -GeoId 14`.

### Finding the right values

| Value | Where to find it |
|---|---|
| Language | Microsoft list [Available languages for Windows](https://learn.microsoft.com/windows-hardware/manufacture/desktop/available-language-packs-for-windows), column "Language/region tag" |
| Culture | Run `[System.Globalization.CultureInfo]::GetCultures("SpecificCultures") \| Select-Object Name, DisplayName` |
| GeoId | Run `[System.Globalization.RegionInfo]::new("AT").GeoId` (replace `AT` with the ISO country code) or see the [Table of Geographical Locations](https://learn.microsoft.com/windows/win32/intl/table-of-geographical-locations) |

Common GeoIds: Austria `14`, Germany `94`, Switzerland `223`, United States `244`, United Kingdom `242`, Netherlands `176`, Slovakia `143`, Czech Republic `75`, Hungary `109`, China `45`.

## 📦 Packaging

Put only the script into a source folder and create the `.intunewin` file:

```
IntuneWinAppUtil.exe -c .\Source -s Set-DeviceLanguage.ps1 -o .\Output
```

You need this package only once. Every language and both scenarios use the same `.intunewin` file, only the install command and the detection rule differ.

## 🚀 Deployment

### Autopilot app

Sets the language during device setup, before the first user signs in.

| Setting | Value |
|---|---|
| Install command | `%windir%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Set-DeviceLanguage.ps1 -Language "de-DE" -Culture "de-AT" -GeoId 14 -InitialSetup` |
| Uninstall command | `reg.exe delete "HKLM\SOFTWARE\CompanyName\DeviceLanguage" /v InitialLanguage /f /reg:64` |
| Install behavior | System |
| Device restart behavior | Determine behavior based on return codes |
| Return codes | `3010` = Soft reboot (default) |
| Detection rule | Registry, key `HKEY_LOCAL_MACHINE\SOFTWARE\CompanyName\DeviceLanguage`, value `InitialLanguage`, string comparison, equals `de-DE` |
| 32-bit app on 64-bit clients | No |
| Assignment | Required, device group |
| Enrollment Status Page | Add as blocking app |

Use dynamic device groups or Autopilot group tags if different locations need different languages.

### Company Portal apps

One app per language, all based on the same package. Users pick their language in the Company Portal and click Install.

| Setting | Value |
|---|---|
| Name | For example `Windows Language: English (US)` |
| Install command | `%windir%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File .\Set-DeviceLanguage.ps1 -Language "en-US" -Culture "de-AT" -GeoId 14` |
| Uninstall command | `reg.exe delete "HKLM\SOFTWARE\CompanyName\DeviceLanguage" /v Language /f /reg:64` |
| Install behavior | System |
| Allow available uninstall | No |
| Device restart behavior | Determine behavior based on return codes |
| Return codes | `3010` = Soft reboot (default) |
| Detection rule | Registry, key `HKEY_LOCAL_MACHINE\SOFTWARE\CompanyName\DeviceLanguage`, value `Language`, string comparison, equals `en-US` |
| 32-bit app on 64-bit clients | No |
| Assignment | Available, user group |

Tip for the app description: *"Changes the Windows display language. The download can take up to 20 minutes, a restart is required afterwards."*

### Example app set

| Company Portal app | Parameters |
|---|---|
| Windows-Sprache: Deutsch | `-Language "de-DE" -Culture "de-AT" -GeoId 14` |
| Windows Language: English (US) | `-Language "en-US" -Culture "de-AT" -GeoId 14` |
| Windows Language: English (UK) | `-Language "en-GB" -Culture "de-AT" -GeoId 14` |
| Windows-taal: Nederlands | `-Language "nl-NL" -Culture "de-AT" -GeoId 14` |
| Jazyk Windows: Slovenčina | `-Language "sk-SK" -Culture "de-AT" -GeoId 14` |
| Jazyk Windows: Čeština | `-Language "cs-CZ" -Culture "de-AT" -GeoId 14` |
| Windows nyelv: Magyar | `-Language "hu-HU" -Culture "de-AT" -GeoId 14` |
| Windows 语言: 中文 (简体) | `-Language "zh-CN" -Culture "de-AT" -GeoId 14` |

## 🔍 Detection logic

The script writes two markers to the same registry key:

| Value | Written by | Used by |
|---|---|---|
| `Language` | Every run | Company Portal apps |
| `InitialLanguage` | Only runs with `-InitialSetup` | Autopilot app |
| `Culture`, `GeoId`, `LastChanged` | Every run | Information only |

Why two markers? Intune re-evaluates required apps regularly. If the Autopilot app used the `Language` marker, a user switching to English in the Company Portal would make the required German app "not installed", and Intune would switch the device back to German at the next check. With its own `InitialLanguage` marker the Autopilot app stays detected forever, and users can switch freely.

When a user installs another language from the Company Portal, the `Language` marker is overwritten. The previously installed language app automatically shows as not installed again and can be selected anytime.

Users can still change the language in the Settings app. The Company Portal then keeps showing the last language installed through the portal as "Installed". That is by design.

## 📝 Logging

Everything is written to:

```
%ProgramData%\Microsoft\IntuneManagementExtension\Logs\Set-DeviceLanguage.log
```

The log is appended on every run and is included in Intune "Collect diagnostics".

| Exit code | Meaning |
|---|---|
| `3010` | Success, restart required |
| `1` | Prerequisite check failed, language installation failed, or system settings could not be applied |

A failing user part is logged as an error but does not fail the app. The system settings are applied anyway and the user gets them at the latest when a new profile is created.

## ⚠️ Good to know

- **Do not combine** this with the Administrative Template policies *"Restricts the UI languages Windows should use for the selected user"* or *"Restrict selection of Windows menus and dialogs language"*. They lock the display language and block the user's choice.
- **Time zone** is not touched on purpose. Use the Settings Catalog policy *Time Language Settings > Configure Time Zone* or keep automatic time zone detection.
- **Shared devices:** Welcome screen, system locale and defaults for new profiles apply to everybody on the device.
- **Download time:** `Install-Language` can take up to 20 minutes. During the ESP the display language may switch a few times before it settles.
- **Restart:** the display language only takes effect after a restart or sign-out. Intune handles this through return code `3010`.
- **Enterprise State Roaming** can bring previously used languages back to the user's language list.
- **Wipe and reset:** installed language packs survive an Intune wipe, the device may come back in the last configured language.
- **Localized account names:** a non-English system localizes built-in account names. Use SIDs instead of names in scripts and policies.
- **No Store LXP needed:** `Install-Language` pulls the language pack and the language features, a separate Local Experience Pack deployment is not required.

## 🛠️ Troubleshooting

| Symptom | Check |
|---|---|
| App fails with exit code 1 | Log file, first lines show the failed prerequisite or the error from `Install-Language` |
| `Install-Language` fails | Device can reach Windows Update / Features on Demand, no WSUS policy blocks optional content |
| Display language did not change | Device was restarted, `-Language` is a language from the Microsoft list (not just a culture) |
| User settings not applied | Log shows the result of the scheduled task for that user |
| Autopilot app reinstalls after a user change | Detection rule of the Autopilot app uses `InitialLanguage`, not `Language` |
| Detection never succeeds | "Associated with a 32-bit app on 64-bit clients" is set to No |

## 👤 Author

**Daniel Fraubaum**
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.