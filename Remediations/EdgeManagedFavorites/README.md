# Intune Remediation: Edge Managed Favorites

Author: **Daniel Fraubaum | headsinthecloud.blog**  
Version: **1.2**  
Last update: **2026-11-24**

This folder contains **Intune Remediation** pairs that deploy Microsoft Edge managed favorites from **several independent remediations** into one merged favorites tree.  
The Edge policy `ManagedFavorites` is a single JSON value. If two Settings Catalog profiles or two scripts set it, the last one wins and the other favorites are gone. This package solves that: every remediation owns one **favorites set**, and every run rebuilds the policy from **all** sets on the device.

The package comes in two variants: **HKLM** writes the favorites as a device policy, **HKCU** writes them as a user policy.

---

## Choose one variant: HKLM or HKCU

> [!IMPORTANT]
> **Do not mix the variants.** Use either the HKLM pair or the HKCU pair for all favorites remediations in your tenant, never both. The variants use separate staging keys, so they do not merge with each other. If a device gets both, Edge applies the device policy (HKLM) and ignores the user policy (HKCU), so the favorites of the HKCU remediations are silently missing.

| | HKLM variant | HKCU variant |
| --- | --- | --- |
| Scripts | `EdgeManagedFavorites_HKLM_Detect.ps1`<br>`EdgeManagedFavorites_HKLM_Remediate.ps1` | `EdgeManagedFavorites_HKCU_Detect.ps1`<br>`EdgeManagedFavorites_HKCU_Remediate.ps1` |
| Edge policy | `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `HKEY_USERS\<SID>\Software\Policies\Microsoft\Edge` of every signed-in user |
| `edge://policy`, column "Applies to" | Machine | Current user |
| Staging key | `HKLM:\SOFTWARE\YourCompany\EdgeManagedFavorites` | `HKLM:\SOFTWARE\YourCompany\EdgeManagedFavoritesUser` |
| Runs as | SYSTEM | SYSTEM |
| Users who are not signed in | Covered, the policy applies to everyone on the device | Get the policy on the first run after they sign in |

**Why the HKCU variant runs as SYSTEM.** Standard users only have read access to `HKCU\Software\Policies`, so a remediation that runs with the logged-on credentials cannot write an Edge policy there. Local admins don't help either, because Intune runs user scripts with the filtered UAC token. The HKCU variant therefore runs as SYSTEM and writes the policy to the hive of every loaded user profile below `HKEY_USERS` (local, Active Directory and Entra ID accounts). The staging key stays in HKLM on purpose, because users can change their own HKCU.

**Switching the variant.** Before you assign the other variant, remove the current one: run every remediation of the current variant once with `$RemoveSet = $true`, or delete its policy value and staging key manually.

---

## What this package does

- Writes the favorites of this remediation (a flat list of `Path`, `Name`, `Url`) to a staging key  
  `<RegistryBasePath>\Sets\<SetName>`
- Reads all sets on the device and builds the Edge policy value `ManagedFavorites` (`REG_SZ`, JSON)  
  - HKLM variant: `HKLM:\SOFTWARE\Policies\Microsoft\Edge`  
  - HKCU variant: `Software\Policies\Microsoft\Edge` in the hive of every loaded user profile
- Merges folders with the same path from different sets, **case-insensitive** (`Admin Portals` and `admin portals` become one folder)
- Removes duplicate links (same path, name and URL)
- Sorts every level alphabetically: **folders first, then links**
- Sets the name of the managed favorites root folder (`toplevel_name`) from `$TopLevelName`
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

- `EdgeManagedFavorites_HKLM_Detect.ps1`  
  Detection script of the HKLM variant. Returns exit code `0` if this set is present and current in the staging key, no stale set is waiting for cleanup and the Edge device policy matches the merged result of all sets. Returns `1` otherwise. Changes nothing.

- `EdgeManagedFavorites_HKLM_Remediate.ps1`  
  Remediation script of the HKLM variant. Writes or removes this set, removes stale sets and rebuilds the Edge device policy value.

- `EdgeManagedFavorites_HKCU_Detect.ps1`  
  Detection script of the HKCU variant. Same checks as the HKLM variant, but compares the Edge user policy of every loaded user profile. Returns `0` if no user is signed in and the staging key is current. Changes nothing.

- `EdgeManagedFavorites_HKCU_Remediate.ps1`  
  Remediation script of the HKCU variant. Writes or removes this set, removes stale sets and writes the merged Edge user policy value to every loaded user profile. Returns `1` if a single profile fails and names it in the output.

---

## How several remediations work together

Create one remediation per favorites set, for example **General** for all devices and **IT** for the IT admins. Use the same two scripts of **one** variant in every remediation and change only these values:

- **`$SetName` must be different** in every remediation. It is the name of the set in the staging key. Two remediations with the same `$SetName` overwrite each other.
- **`$TopLevelName` must be the same** in every remediation, for example `"Company Favorites"`. Edge has only one managed favorites root folder, so all sets end up in the same folder. If the values differ, the set that comes first alphabetically by `$SetName` wins and the name depends on which sets a device has.
- **`$Favorites`** is the content of the set and is usually different.
- **`$RegistryBasePath`, `$StaleAfterDays`, `$EdgePolicyPath` and `$EdgePolicyName` must be the same** in every remediation.

```text
<RegistryBasePath>\Sets
├── General   Favorites (JSON), TopLevelName, LastUpdated
└── IT        Favorites (JSON), TopLevelName, LastUpdated
                    │
                    ▼  merged on every remediation run
HKLM variant:  HKLM:\SOFTWARE\Policies\Microsoft\Edge\ManagedFavorites
HKCU variant:  HKEY_USERS\<SID>\Software\Policies\Microsoft\Edge\ManagedFavorites (every signed-in user)
```

- **Stale cleanup.** Every set stores `LastUpdated` (UTC). A set that was not refreshed for `$StaleAfterDays` days is ignored and deleted by the next favorites remediation that runs. This is how favorites disappear after you unassign a remediation.
- **Refresh.** Detection reports "refresh due" when the own set is older than `$RefreshAfterDays` days, so the remediation renews the timestamp before other remediations consider it stale.
- **Immediate removal.** Set `$RemoveSet = $true` in a remediation to remove its set right away instead of waiting for the stale cleanup.

---

## Parameters

The Detect and the Remediate script of one remediation must always contain the **same Parameters block**. The block is marked with `PARAMETERS START` and `PARAMETERS END`:

1. Fill in your values between the two markers in the **Detect** script.
2. Copy everything from `PARAMETERS START` to `PARAMETERS END` **1:1** into the **Remediate** script and replace the same block there.

Do not change anything outside the block. If the two blocks differ, detection checks other values than the remediation writes.

| Parameter | Default | Description |
| --- | --- | --- |
| `$SetName` | `General` | Unique name of this favorites set, also the name of the staging key. **Use a different value in every remediation.** Must not be empty or contain `\ / * ? [ ]` |
| `$TopLevelName` | `Company Favorites` | Name of the managed favorites root folder in Edge. Empty = Edge default **Managed favorites**. **Must be identical in every favorites remediation.** If the values differ, the set that comes first alphabetically by `SetName` wins |
| `$Favorites` | 4 sample links | Favorites of this set. `Path` = folders separated by `/`, empty = directly in the root folder. `Name` and `Url` are required |
| `$RemoveSet` | `$false` | `$true` removes this set from the device and rebuilds the policy from the remaining sets |
| `$RegistryBasePath` | HKLM: `HKLM:\SOFTWARE\YourCompany\EdgeManagedFavorites`<br>HKCU: `HKLM:\SOFTWARE\YourCompany\EdgeManagedFavoritesUser` | Staging location for all sets. Replace `YourCompany` with your own name. Must be identical in **every** favorites remediation |
| `$StaleAfterDays` | `30` | Sets not refreshed for this many days are ignored and deleted. `0` = never. Must be identical in every favorites remediation |
| `$RefreshAfterDays` | `7` | Detection requests a refresh of the own set after this many days. Must be at least `1` and lower than `$StaleAfterDays` (unless `$StaleAfterDays` is `0`), otherwise both scripts fail with an error |
| `$EdgePolicyPath` | HKLM: `HKLM:\SOFTWARE\Policies\Microsoft\Edge`<br>HKCU: `Software\Policies\Microsoft\Edge` | Registry key of the Edge policy. In the HKCU variant the path is relative to the hive of every loaded user profile (`HKEY_USERS\<SID>`) |
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
   - Detection script file: `EdgeManagedFavorites_HKLM_Detect.ps1` or `EdgeManagedFavorites_HKCU_Detect.ps1`  
   - Remediation script file: the matching `EdgeManagedFavorites_HKLM_Remediate.ps1` or `EdgeManagedFavorites_HKCU_Remediate.ps1`  
   - Run this script using the logged-on credentials: **No** (runs as SYSTEM, also for the HKCU variant)  
   - Enforce script signature check: **No**  
   - Run script in 64-bit PowerShell: **Yes**

3. **Assignments**  
   - Assign to the device groups in scope

4. **Schedule**  
   - HKLM variant: **Daily**  
   - HKCU variant: **Daily**, or **Hourly** if users who sign in for the first time should get their favorites faster

Repeat this for every favorites set with its own `$SetName`, the same `$TopLevelName` and the same variant.

---

## Notes

- **Do not mix the variants.** Use either HKLM or HKCU for all favorites remediations, see [Choose one variant](#choose-one-variant-hklm-or-hkcu).
- **Do not mix with other ManagedFavorites sources.** A Settings Catalog profile, GPO or another script that sets `ManagedFavorites` overwrites the merged value (or gets overwritten by it). A device policy from any source also wins over the HKCU variant.
- **Dynamic refresh.** Edge picks up the new policy without a restart. Check `edge://policy` if favorites do not show up.
- **Folder names.** When the same folder is written in different upper/lower case in several sets, the spelling of the set that comes first by `SetName` is used.
- **Devices that were offline for a long time.** If a device was off for longer than `$StaleAfterDays`, the first favorites remediation that runs removes all other sets as stale. They come back as soon as their own remediations run.
- **Detection compares case-sensitive.** A URL or name change in upper/lower case only is detected and deployed.
- **HKCU variant and signed-out users.** Only loaded user profiles are updated. A user who is not signed in keeps the last value in the own profile and gets the current favorites on the first run after the next sign-in. All signed-in users of a device get the same favorites.
- **Removal.** Unassigning a remediation removes its favorites after `$StaleAfterDays` days, the next time another favorites remediation runs. When the last remediation is gone, run one remediation with `$RemoveSet = $true` first, or delete the policy value `ManagedFavorites` and the `$RegistryBasePath` key manually. In the HKCU variant the policy value is in every user profile.

---

## Disclaimer

These scripts are provided as-is. Test thoroughly in a non-production environment before broad deployment.

---

More Intune content on **[headsinthecloud.blog](https://headsinthecloud.blog)**
