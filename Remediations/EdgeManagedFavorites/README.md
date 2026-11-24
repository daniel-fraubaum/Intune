# Intune Remediation: Edge Managed Favorites

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.1**  
Last update: **2026-11-24**

This folder contains an **Intune Remediation** pair that deploys Microsoft Edge managed favorites from **several independent remediations** into one merged favorites tree.  
The Edge policy `ManagedFavorites` is a single JSON value. If two Settings Catalog profiles or two scripts set it, the last one wins and the other favorites are gone. This package solves that: every remediation owns one **favorites set**, and every run rebuilds the policy from **all** sets on the device.

---

## What this package does

- Writes the favorites of this remediation (a flat list of `Path`, `Name`, `Url`) to a staging key  
  `HKLM:\SOFTWARE\YourCompany\EdgeManagedFavorites\Sets\<SetName>`
- Reads all sets on the device and builds the Edge policy value  
  `HKLM:\SOFTWARE\Policies\Microsoft\Edge\ManagedFavorites` (`REG_SZ`, JSON)
- Merges folders with the same path from different sets, **case-insensitive** (`Admin Portals` and `admin portals` become one folder)
- Removes duplicate links (same path, name and URL)
- Sorts every level alphabetically: **folders first, then links**
- Sets the name of the managed favorites root folder (`toplevel_name`) from the first set, sorted by `SetName`, that defines one
- Cleans up sets of remediations that are no longer assigned (stale sets)
- Removes the policy value when no favorites are left
- Serializes parallel runs of several favorites remediations with a global mutex

---

## Result

With the default parameters Edge shows this tree in the **Company Favorites** folder:

```text
Company Favorites
├── Admin Portals
│   ├── Security
│   │   └── Defender
│   ├── Entra
│   └── Intune
└── Microsoft
```

The resulting policy value:

```json
[{"toplevel_name":"Company Favorites"},{"name":"Admin Portals","children":[{"name":"Security","children":[{"name":"Defender","url":"https://security.microsoft.com"}]},{"name":"Entra","url":"https://entra.microsoft.com"},{"name":"Intune","url":"https://intune.microsoft.com"}]},{"name":"Microsoft","url":"https://www.microsoft.com"}]
```

---

## Files

- `EdgeManagedFavorites_Detect.ps1`  
  Detection script. Returns exit code `0` if this set is present and current in the staging key, no stale set is waiting for cleanup and the Edge policy matches the merged result of all sets. Returns `1` otherwise. Changes nothing.

- `EdgeManagedFavorites_Remediate.ps1`  
  Remediation script. Writes or removes this set, removes stale sets and rebuilds the Edge policy value.

---

## How several remediations work together

Create one remediation per favorites set, for example **General** for all devices and **IT** for the IT admins. Use the same two scripts, but a **different `$SetName`** and different `$Favorites` in each pair.

```text
HKLM:\SOFTWARE\YourCompany\EdgeManagedFavorites\Sets
├── General   Favorites (JSON), TopLevelName, LastUpdated
└── IT        Favorites (JSON), TopLevelName, LastUpdated
                    │
                    ▼  merged on every remediation run
HKLM:\SOFTWARE\Policies\Microsoft\Edge\ManagedFavorites
```

- **Stale cleanup.** Every set stores `LastUpdated` (UTC). A set that was not refreshed for `$StaleAfterDays` days is ignored and deleted by the next favorites remediation that runs. This is how favorites disappear after you unassign a remediation.
- **Refresh.** Detection reports "refresh due" when the own set is older than `$RefreshAfterDays` days, so the remediation renews the timestamp before other remediations consider it stale.
- **Immediate removal.** Set `$RemoveSet = $true` in a remediation to remove its set right away instead of waiting for the stale cleanup.

---

## Parameters

Keep the **Parameters section identical** in the Detect and the Remediate script of one remediation.

| Parameter | Default | Description |
| --- | --- | --- |
| `$SetName` | `General` | Unique name of this favorites set, also the name of the staging key. Use a different value in every remediation. Must not be empty or contain `\ / * ? [ ]` |
| `$TopLevelName` | `Company Favorites` | Name of the managed favorites root folder in Edge. Empty = Edge default **Managed favorites**. If several sets define a name, the set that comes first alphabetically by `SetName` wins |
| `$Favorites` | 4 sample links | Favorites of this set. `Path` = folders separated by `/`, empty = directly in the root folder. `Name` and `Url` are required |
| `$RemoveSet` | `$false` | `$true` removes this set from the device and rebuilds the policy from the remaining sets |
| `$RegistryBasePath` | `HKLM:\SOFTWARE\YourCompany\EdgeManagedFavorites` | Staging location for all sets. Replace `YourCompany` with your own name. Must be identical in **every** favorites remediation |
| `$StaleAfterDays` | `30` | Sets not refreshed for this many days are ignored and deleted. `0` = never. Must be identical in every favorites remediation |
| `$RefreshAfterDays` | `7` | Detection requests a refresh of the own set after this many days. Must be at least `1` and lower than `$StaleAfterDays` (unless `$StaleAfterDays` is `0`), otherwise both scripts fail with an error |
| `$EdgePolicyPath` | `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | Registry key of the Edge policy |
| `$EdgePolicyName` | `ManagedFavorites` | Name of the Edge policy value |

Example for `$Favorites`:

```powershell
$Favorites = @(
    @{ Path = "";                        Name = "Microsoft"; Url = "https://www.microsoft.com" }
    @{ Path = "Admin Portals";           Name = "Intune";    Url = "https://intune.microsoft.com" }
    @{ Path = "Admin Portals/Security";  Name = "Defender";  Url = "https://security.microsoft.com" }
)
```

Paths are normalized: leading, trailing and double `/` as well as spaces around a folder name are removed, so `/Admin Portals//Security/ ` becomes `Admin Portals/Security`.

---

## Intune setup

1. Go to **Intune admin center**  
   Devices → Scripts and remediations → **Remediations** → **Create**

2. **Settings**  
   - Detection script file: `EdgeManagedFavorites_Detect.ps1`  
   - Remediation script file: `EdgeManagedFavorites_Remediate.ps1`  
   - Run this script using the logged-on credentials: **No** (runs as SYSTEM)  
   - Enforce script signature check: **No**  
   - Run script in 64-bit PowerShell: **Yes**

3. **Assignments**  
   - Assign to the device groups in scope

4. **Schedule**  
   - **Daily**

Repeat this for every favorites set with its own `$SetName`.

---

## Notes

- **Do not mix with other ManagedFavorites sources.** A Settings Catalog profile, GPO or another script that sets `ManagedFavorites` overwrites the merged value (or gets overwritten by it).
- **Dynamic refresh.** Edge picks up the new policy without a restart. Check `edge://policy` if favorites do not show up.
- **Folder names.** When the same folder is written in different upper/lower case in several sets, the spelling of the set that comes first by `SetName` is used.
- **Devices that were offline for a long time.** If a device was off for longer than `$StaleAfterDays`, the first favorites remediation that runs removes all other sets as stale. They come back as soon as their own remediations run.
- **Detection compares case-sensitive.** A URL or name change in upper/lower case only is detected and deployed.
- **Removal.** Unassigning a remediation removes its favorites after `$StaleAfterDays` days, the next time another favorites remediation runs. When the last remediation is gone, delete the policy value `ManagedFavorites` and the `$RegistryBasePath` key manually, or run one remediation with `$RemoveSet = $true` first.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
