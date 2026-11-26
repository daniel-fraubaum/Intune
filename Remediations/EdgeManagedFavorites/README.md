# ⭐ EdgeManagedFavorites

The Edge policy `ManagedFavorites` is a single JSON value. If two Settings Catalog profiles or two scripts set it, the last one wins and the other favorites are gone.

This package deploys Microsoft Edge managed favorites from **several independent remediations** into one merged favorites tree. Every remediation owns one **favorites set**, and the policy is always rebuilt from **all** sets. The package comes in two variants: **HKLM** writes the favorites as a device policy, so every user on a device gets all sets assigned to that device. **HKCU** writes the favorites as a user policy, so every user only gets the sets assigned to that user, also when several users share a device.

## ✨ Features

- Writes the favorites of each remediation (a flat list of `Path`, `Name`, `Url`) to a staging key `<RegistryBasePath>\Sets\<SetName>`
- Builds the Edge policy value `ManagedFavorites` (`REG_SZ`, JSON) from the sets:
  - HKLM variant: from all sets of the device, in `HKLM:\SOFTWARE\Policies\Microsoft\Edge`
  - HKCU variant: from the sets of each user, in `Software\Policies\Microsoft\Edge` of that user
- Merges folders with the same path from different sets, **case-insensitive** (`Admin Portals` and `admin portals` become one folder)
- Removes duplicate links (same path, name and URL)
- Sorts every level alphabetically: **folders first, then links**
- Sets the name of the managed favorites root folder (`toplevel_name`) from `$TopLevelName`
- Normalizes folder paths, so small typing differences do not create extra folders
- Cleans up sets of remediations that are no longer assigned (stale sets)
- Removes the policy value when no favorites are left. Never recreates the Edge policy key, so other Edge policies in the same key stay untouched
- HKCU variant: treats the staging key in the user profile as untrusted input and skips sets with invalid content
- Serializes parallel runs of the HKLM remediation and the HKCU merge remediation with the global mutex `Global\EdgeManagedFavoritesMerge`

## ⚙️ How it works

### Choose one variant: HKLM or HKCU

> [!IMPORTANT]
> **Do not mix the variants.** Use either the HKLM scripts or the HKCU scripts for all favorites remediations in your tenant, never both. The variants use separate staging keys, so they do not merge with each other. If a device gets both, Edge applies the device policy (HKLM) and ignores the user policy (HKCU), so the favorites of the HKCU remediations are silently missing.

| | HKLM variant | HKCU variant |
|---|---|---|
| Who gets which favorites | Every user on the device gets all sets assigned to the device | Every user gets only the sets assigned to that user |
| Scripts | One pair per set:<br>`Detect_EdgeManagedFavorites_HKLM.ps1`<br>`Remediate_EdgeManagedFavorites_HKLM.ps1` | One **set pair** per set:<br>`Detect_EdgeManagedFavorites_HKCU_Set.ps1`<br>`Remediate_EdgeManagedFavorites_HKCU_Set.ps1`<br><br>Plus **one merge pair**:<br>`Detect_EdgeManagedFavorites_HKCU_Merge.ps1`<br>`Remediate_EdgeManagedFavorites_HKCU_Merge.ps1` |
| Runs as | SYSTEM | Set pair: the signed-in user<br>Merge pair: SYSTEM |
| Assign to | Device groups | Set pair: user groups<br>Merge pair: device groups |
| Staging key | `HKLM:\SOFTWARE\CompanyName\EdgeManagedFavorites` | `HKCU:\Software\CompanyName\EdgeManagedFavorites` of every user |
| Edge policy | `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | `HKCU:\Software\Policies\Microsoft\Edge` of every user |
| `edge://policy`, column "Applies to" | Machine | Current user |
| Delay | The policy is written in the same run | Up to one merge interval after the set remediation ran |

**Switching the variant.** Before you assign the other variant, remove the current one: run every set remediation of the current variant once with `$RemoveSet = $true` (in the HKCU variant also let the merge remediation run once), or delete its policy values and staging keys manually.

### HKLM variant

| Step | Script | What happens |
|---|---|---|
| 1 | Detect | `Detect_EdgeManagedFavorites_HKLM.ps1` checks that this set is present and current in the staging key (favorites, top level name, refresh not due), or absent with `$RemoveSet = $true`. It also checks that no stale set is waiting for cleanup and that the Edge device policy matches the merged result of all sets. Exit `0` if everything matches, otherwise `1`. Changes nothing |
| 2 | Remediate | `Remediate_EdgeManagedFavorites_HKLM.ps1` takes the global mutex (waits up to 2 minutes), writes or removes this set, removes stale sets of other remediations, merges all sets and writes the Edge device policy value. Removes the value if no favorites are left |

### HKCU variant

The HKCU variant always consists of **one merge remediation** plus **one set remediation per group of favorites**:

| Step | Script | What happens |
|---|---|---|
| 1 | Detect (set) | `Detect_EdgeManagedFavorites_HKCU_Set.ps1` runs as the signed-in user. Exit `0` if this set is present and current in the staging key of the user (or absent with `$RemoveSet = $true`), otherwise `1`. Changes nothing. Does not check the Edge policy, that is the job of the merge remediation |
| 2 | Remediate (set) | `Remediate_EdgeManagedFavorites_HKCU_Set.ps1` runs as the signed-in user. Writes or removes this set in `HKCU:\<RegistryBasePath>\Sets\<SetName>`. Writes `LastUpdated` last, so the merge remediation only picks up a complete set. Never writes the Edge policy. Fails with a clear message when it runs as SYSTEM by mistake |
| 3 | Detect (merge) | `Detect_EdgeManagedFavorites_HKCU_Merge.ps1` runs as SYSTEM. Exit `0` if the Edge user policy of every loaded user profile matches the merged sets of that user and no stale set is waiting for cleanup. Exit `0` if no user is signed in. Otherwise `1`. Changes nothing |
| 4 | Remediate (merge) | `Remediate_EdgeManagedFavorites_HKCU_Merge.ps1` runs as SYSTEM and takes the global mutex. For every loaded user profile it removes stale sets and writes the merged Edge user policy. Exit `1` if a single profile fails, the failed profile is named in the output and the other profiles are still updated |

| | Merge remediation | Set remediation |
|---|---|---|
| Scripts | `Detect_EdgeManagedFavorites_HKCU_Merge.ps1`<br>`Remediate_EdgeManagedFavorites_HKCU_Merge.ps1` | `Detect_EdgeManagedFavorites_HKCU_Set.ps1`<br>`Remediate_EdgeManagedFavorites_HKCU_Set.ps1` |
| How many | **Exactly one** in the tenant | **One per group of favorites**, also for the favorites that everyone gets |
| Contains favorites | No, it only has path parameters | Yes, `$Favorites` of this set |
| Runs as | SYSTEM | The signed-in user |
| Assign to | All devices | The users who should get this set |
| Job | Writes the Edge policy of every user from the sets of that user | Decides **who** gets **which** favorites |

Both parts are always needed:

- **Merge without sets:** nobody gets favorites, because the merge remediation has none of its own.
- **Sets without merge:** the favorites are only stored in the user profile and never reach Edge.

### Why the HKCU variant has two parts

Two Windows and Intune rules work against each other:

1. **Only SYSTEM can write the Edge user policy.** Standard users only have read access to `HKCU\Software\Policies`. A script that runs with the logged-on credentials cannot write the policy. Local admins don't help either, because Intune runs user scripts with the filtered UAC token.
2. **Only the user context knows who an assignment is for.** When a remediation is assigned to a user group and runs as SYSTEM, the script does not learn which user the assignment was meant for. With the logged-on credentials it simply only runs for the users in the group.

No single script can do both, so the work is split:

- The **set remediation** runs as the user and writes its set to the staging key in the profile of that user: `HKCU:\<RegistryBasePath>\Sets\<SetName>`. A user who is not in the assigned group never gets the set.
- The **merge remediation** runs as SYSTEM, goes through every loaded user profile below `HKEY_USERS` (local, Active Directory and Entra ID accounts), reads **only the sets of that user**, removes stale sets, merges the rest and writes the result to the Edge user policy of that user: `HKEY_USERS\<SID>\Software\Policies\Microsoft\Edge\ManagedFavorites`.

### Example: company with two branches and an IT team

Requirements:

- Everyone gets the intranet and the help desk.
- Users in the Vienna branch also get the Vienna room booking, users in the Graz branch the Graz room booking.
- IT admins also get the admin portals.
- All favorites appear in one Edge folder called **Company Favorites**.

You create **five remediations** in Intune:

| Remediation in Intune | Scripts | `$SetName` | Content of `$Favorites` | Assignment | Logged-on credentials |
|---|---|---|---|---|---|
| Edge Favorites - Merge | Merge pair | (none) | (none) | All devices | **No** |
| Edge Favorites - General | Set pair | `General` | Intranet, Help Desk | All users | **Yes** |
| Edge Favorites - Vienna | Set pair | `Vienna` | Room Booking Vienna | User group Vienna | **Yes** |
| Edge Favorites - Graz | Set pair | `Graz` | Room Booking Graz | User group Graz | **Yes** |
| Edge Favorites - IT | Set pair | `IT` | Intune, Entra, Defender | User group IT admins | **Yes** |

The Parameters block of the set remediation **General** (Detect and Remediate contain the same block):

```powershell
$SetName          = "General"
$TopLevelName     = "Company Favorites"
$Favorites = @(
    @{ Path = "";         Name = "Intranet";  Url = "https://intranet.example.com" }
    @{ Path = "";         Name = "Help Desk"; Url = "https://helpdesk.example.com" }
)
$RemoveSet        = $false
$RegistryBasePath = "Software\CompanyName\EdgeManagedFavorites"
$StaleAfterDays   = 30
$RefreshAfterDays = 7
```

The set remediation **Vienna** only differs in `$SetName` and `$Favorites`:

```powershell
$SetName          = "Vienna"
$TopLevelName     = "Company Favorites"
$Favorites = @(
    @{ Path = "Vienna"; Name = "Room Booking"; Url = "https://rooms-vienna.example.com" }
)
$RemoveSet        = $false
$RegistryBasePath = "Software\CompanyName\EdgeManagedFavorites"
$StaleAfterDays   = 30
$RefreshAfterDays = 7
```

**Graz** and **IT** follow the same pattern. The **merge** remediation only contains the paths, `$RegistryBasePath` and `$StaleAfterDays` are the same values as in every set:

```powershell
$RegistryBasePath = "Software\CompanyName\EdgeManagedFavorites"
$StaleAfterDays   = 30
$EdgePolicyPath   = "Software\Policies\Microsoft\Edge"
$EdgePolicyName   = "ManagedFavorites"
```

**What every user gets.** Anna and Chris share one PC in Vienna:

| User | Groups | Sets in the own profile | Edge shows |
|---|---|---|---|
| Anna | Vienna | General, Vienna | Intranet, Help Desk, Vienna folder |
| Chris | Vienna, IT admins | General, Vienna, IT | Intranet, Help Desk, Vienna folder, admin portals |
| Ben | Graz | General, Graz | Intranet, Help Desk, Graz folder |

Chris sees this tree in Edge, Anna sees the same tree without **Admin Portals**, although both use the same PC:

```text
Company Favorites
├── Admin Portals
│   ├── Security
│   │   └── Defender
│   ├── Entra
│   └── Intune
├── Vienna
│   └── Room Booking
├── Help Desk
└── Intranet
```

**What happens on the PC when Anna signs in:**

1. Intune runs the set remediations **General** and **Vienna** for Anna (she is in both groups). They write `General` and `Vienna` to `HKCU:\Software\CompanyName\EdgeManagedFavorites\Sets` of Anna. **IT** and **Graz** do not run for her.
2. Within the next hour the merge remediation runs as SYSTEM. It finds the profile of Anna, merges her two sets and writes the result to her Edge user policy.
3. Edge picks up the policy without a restart.

When Chris signs in on the same PC, the same happens with his three sets in his own profile. The two users never see each other's sets.

### Merging, stale cleanup and refresh

```text
<RegistryBasePath>\Sets
├── General   Favorites (JSON), TopLevelName, LastUpdated
└── IT        Favorites (JSON), TopLevelName, LastUpdated
                    │
                    ▼  merged
HKLM variant:  HKLM:\SOFTWARE\Policies\Microsoft\Edge\ManagedFavorites, on every remediation run, all sets of the device
HKCU variant:  HKCU:\Software\Policies\Microsoft\Edge\ManagedFavorites, by the merge remediation, the sets of this user
```

- **Stale cleanup.** Every set stores `LastUpdated` (UTC). A set that was not refreshed for `$StaleAfterDays` days is ignored and deleted. In the HKLM variant the next favorites remediation that runs does this, in the HKCU variant the merge remediation does it for every user separately. This is how favorites disappear after you unassign a remediation or remove a user from the group.
- **Refresh.** Detection reports "refresh due" when the own set is older than `$RefreshAfterDays` days, so the remediation renews the timestamp before the set counts as stale.
- **Immediate removal.** Set `$RemoveSet = $true` in a remediation to remove its set right away instead of waiting for the stale cleanup. In the HKCU variant the set is removed for the users the remediation is assigned to, and the merge remediation updates their policy on its next run.
- **Missing timestamp.** HKLM variant: a set without a valid `LastUpdated` counts as stale and is deleted. HKCU merge: such a set counts as incomplete, it is skipped, kept and named in the output, so a set that is still being written is not lost.
- **Invalid content (HKCU).** A set with invalid JSON or without `Name` or `Url` is skipped and named in the output. The other sets of that user and all other users are processed normally.

### Result with the default parameters

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

## 📋 Requirements

| Requirement | Details |
|---|---|
| Windows | Windows 10 or Windows 11 |
| Browser | Microsoft Edge, reads the `ManagedFavorites` policy from the registry |
| PowerShell | Windows PowerShell 5.1, 64-bit |
| Context | HKLM pair: SYSTEM<br>HKCU set pair: the signed-in user<br>HKCU merge pair: SYSTEM |
| Other policies | No other source of `ManagedFavorites` (Settings Catalog, GPO, other scripts) |

## 🔧 Configuration

Adjust the Parameters block at the top of the scripts before you upload them. The Detect and the Remediate script of one remediation must always contain the **same Parameters block**. The block is marked with `PARAMETERS START` and `PARAMETERS END`:

1. Fill in your values between the two markers in the **Detect** script.
2. Copy everything from `PARAMETERS START` to `PARAMETERS END` **1:1** into the **Remediate** script and replace the same block there.

Do not change anything outside the block. If the two blocks differ, detection checks other values than the remediation writes.

### HKLM pair and HKCU set pair

| Variable | Default | Description |
|---|---|---|
| `$SetName` | `General` | Unique name of this favorites set, also the name of the staging key. **Use a different value in every remediation.** Must not be empty or contain `\ / * ? [ ]` |
| `$TopLevelName` | `Company Favorites` | Name of the managed favorites root folder in Edge. Empty = Edge default **Managed favorites**. **Must be identical in every favorites remediation.** If the values differ, the set that comes first alphabetically by `SetName` wins |
| `$Favorites` | 4 sample links | Favorites of this set. `Path` = folders separated by `/`, empty = directly in the root folder. `Name` and `Url` are required |
| `$RemoveSet` | `$false` | `$true` removes this set. HKLM: from the device, the policy is rebuilt from the remaining sets. HKCU: from the profile of the user, the merge remediation rebuilds the policy |
| `$RegistryBasePath` | HKLM: `HKLM:\SOFTWARE\CompanyName\EdgeManagedFavorites`<br>HKCU: `Software\CompanyName\EdgeManagedFavorites` | Staging location of the sets. Replace `CompanyName` with your own name. In the HKCU variant the path is relative to the user profile (no `HKCU:\`), otherwise the scripts fail. Must be identical in **every** favorites remediation (HKCU: also in the merge remediation) |
| `$StaleAfterDays` | `30` | Sets not refreshed for this many days are ignored and deleted. `0` = never. Must be identical in every favorites remediation (HKCU: also in the merge remediation) |
| `$RefreshAfterDays` | `7` | Detection requests a refresh of the own set after this many days. Must be at least `1` and lower than `$StaleAfterDays` (unless `$StaleAfterDays` is `0`, then `0` = never is allowed), otherwise both scripts fail with an error |
| `$EdgePolicyPath` | `HKLM:\SOFTWARE\Policies\Microsoft\Edge` | HKLM pair only. Registry key of the Edge policy |
| `$EdgePolicyName` | `ManagedFavorites` | HKLM pair only. Name of the Edge policy value |

### HKCU merge pair

| Variable | Default | Description |
|---|---|---|
| `$RegistryBasePath` | `Software\CompanyName\EdgeManagedFavorites` | Staging location of the sets, relative to every user profile. Must be identical to `$RegistryBasePath` in every set remediation |
| `$StaleAfterDays` | `30` | Sets not refreshed for this many days are deleted. `0` = never. Must be identical to `$StaleAfterDays` in every set remediation |
| `$EdgePolicyPath` | `Software\Policies\Microsoft\Edge` | Registry key of the Edge policy, relative to every user profile (`HKEY_USERS\<SID>`) |
| `$EdgePolicyName` | `ManagedFavorites` | Name of the Edge policy value |

### Favorites

Example for `$Favorites`:

```powershell
$Favorites = @(
    @{ Path = "";                        Name = "Microsoft"; Url = "https://www.microsoft.com" }
    @{ Path = "Admin Portals";           Name = "Intune";    Url = "https://intune.microsoft.com" }
    @{ Path = "Admin Portals/Security";  Name = "Defender";  Url = "https://security.microsoft.com" }
)
```

Paths are normalized: leading, trailing and double `/` as well as spaces around a folder name are removed, so `/Admin Portals//Security/ ` becomes `Admin Portals/Security`.

### Several remediations

Create one remediation per favorites set, for example **General** for all users and **IT** for the IT admins. Use the same scripts of **one** variant in every remediation and change only these values:

- **`$SetName` must be different** in every remediation. It is the name of the set in the staging key. Two remediations with the same `$SetName` overwrite each other.
- **`$TopLevelName` must be the same** in every remediation, for example `"Company Favorites"`. Edge has only one managed favorites root folder, so all sets end up in the same folder. If the values differ, the set that comes first alphabetically by `$SetName` wins and the name depends on which sets a device or user has.
- **`$Favorites`** is the content of the set and is usually different.
- **`$RegistryBasePath` and `$StaleAfterDays` must be the same** in every remediation. In the HKCU variant they must also be the same in the merge remediation.
- **HKLM variant:** `$EdgePolicyPath` and `$EdgePolicyName` must be the same in every remediation.

## 🚀 Deployment

Intune admin center > **Devices** > **Scripts and remediations** > **Remediations** > **Create**

> [!IMPORTANT]
> **Choose one variant and do not mix them.** Deploy either the HKLM pair or the HKCU pairs (set and merge) in your tenant, never both. On a device with both, Edge applies the device policy and the HKCU favorites are silently missing. See [Choose one variant](#choose-one-variant-hklm-or-hkcu).

### HKLM pair

One remediation per favorites set:

| Setting | Value |
|---|---|
| Detection script file | `Detect_EdgeManagedFavorites_HKLM.ps1` |
| Remediation script file | `Remediate_EdgeManagedFavorites_HKLM.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups |
| Schedule | Daily |

### HKCU set pair

One remediation per favorites set:

| Setting | Value |
|---|---|
| Detection script file | `Detect_EdgeManagedFavorites_HKCU_Set.ps1` |
| Remediation script file | `Remediate_EdgeManagedFavorites_HKCU_Set.ps1` |
| Run this script using the logged-on credentials | Yes (signed-in user) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | User groups. Assigning a device group gives the set to every user who signs in on those devices |
| Schedule | Daily |

### HKCU merge pair

**Exactly one** merge remediation in the tenant:

| Setting | Value |
|---|---|
| Detection script file | `Detect_EdgeManagedFavorites_HKCU_Merge.ps1` |
| Remediation script file | `Remediate_EdgeManagedFavorites_HKCU_Merge.ps1` |
| Run this script using the logged-on credentials | No (SYSTEM) |
| Enforce script signature check | No |
| Run script in 64-bit PowerShell | Yes |
| Assignment | Device groups that contain all devices where users with a set remediation sign in |
| Schedule | Hourly, so changes of the set remediations reach Edge quickly |

Repeat the set remediation for every favorites set with its own `$SetName`, the same `$TopLevelName` and the same variant.

### Common changes

| Task | What to do |
|---|---|
| New branch, for example Linz | Create one more set remediation with `$SetName = "Linz"` and assign it to the user group Linz. The merge remediation stays as it is |
| Change the favorites of a set | Change `$Favorites` in the Detect and Remediate script of that set remediation. HKCU: the change reaches Edge with the next merge run |
| User moves from Vienna to Graz | Change the group membership. Graz is added on the next run of the Graz set remediation. Vienna is no longer refreshed and the merge remediation removes it after `$StaleAfterDays` days |
| Remove a set from all users right away | Set `$RemoveSet = $true` in that set remediation and keep it assigned until it ran for the users |
| Branch defined by devices, not by users | Assign the set remediation to a device group instead of a user group. Then every user who signs in on these devices gets the set |

## 🧪 Testing

### HKLM pair

1. Copy the scripts to `C:\Temp` on a test device. Run the detection as SYSTEM with [PsExec](https://learn.microsoft.com/sysinternals/downloads/psexec) from an elevated prompt:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Detect_EdgeManagedFavorites_HKLM.ps1
   ```

   On a fresh device it returns `Not compliant: set "General" missing; ...`.
2. Run `Remediate_EdgeManagedFavorites_HKLM.ps1` the same way.
3. Check the set and the policy:

   ```
   reg query "HKLM\SOFTWARE\CompanyName\EdgeManagedFavorites\Sets" /s
   reg query "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v ManagedFavorites
   ```

4. Run the detection again. It returns `Compliant: set "General" current, merged sets: General.`
5. In Edge open `edge://policy` and click **Reload policies**. `ManagedFavorites` shows "Applies to" **Machine**, and the favorites bar shows the **Company Favorites** folder.

### HKCU set pair and merge pair

1. Sign in with a normal user account. Run the set remediation in a normal (not elevated) PowerShell:

   ```
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediate_EdgeManagedFavorites_HKCU_Set.ps1
   ```

   It returns `Set "General" written for <user>. The merge remediation applies it to Edge on its next run.`
2. Check the set in the profile of the user:

   ```
   reg query "HKCU\Software\CompanyName\EdgeManagedFavorites\Sets" /s
   ```

3. From an elevated prompt run the merge remediation as SYSTEM:

   ```
   psexec -s C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Temp\Remediate_EdgeManagedFavorites_HKCU_Merge.ps1
   ```

4. As the user, check the policy: `reg query "HKCU\Software\Policies\Microsoft\Edge" /v ManagedFavorites`. In `edge://policy` the value shows "Applies to" **Current user**.
5. Run `Detect_EdgeManagedFavorites_HKCU_Merge.ps1` with `psexec -s`. It returns `Compliant: user profiles: <user> (General).`

## 📝 Logging

The scripts write no log files. Everything goes to the output that Intune shows in the device status of each remediation (pre-remediation detection output, remediation output, post-remediation detection output):

- Detection lists every issue, for example `set "General" missing`, `refresh due`, `stale set "IT" pending cleanup` or `Edge ManagedFavorites policy differs from merged result`.
- The HKLM remediation names the merged sets, removed stale sets and `No favorites left, policy value removed.` if that happened.
- The merge pair names every user profile with its sets, removed stale sets and notes on invalid or incomplete sets, and the profiles that failed.

| Exit code | Meaning |
|---|---|
| `0` | Detect: compliant (merge pair: also when no user profile is loaded). Remediate: set and policy written |
| `1` | Detect: not compliant, or the check failed. Remediate: failed, for example invalid parameters, set pair running as SYSTEM, timeout after 2 minutes waiting for the mutex, or the merge failed for at least one user profile |

## ⚠️ Good to know

- **Do not mix the variants.** Use either HKLM or HKCU for all favorites remediations, see [Choose one variant](#choose-one-variant-hklm-or-hkcu).
- **Do not mix with other ManagedFavorites sources.** A Settings Catalog profile, GPO or another script that sets `ManagedFavorites` overwrites the merged value (or gets overwritten by it). A device policy from any source also wins over the HKCU variant.
- **HKCU variant without merge remediation.** The set remediations only fill the staging keys. Without the merge remediation nothing reaches Edge.
- **The staging key belongs to the user.** Users can change their own staging key and thereby add favorites to their own managed favorites. This never affects other users. The merge remediation treats the staging key as untrusted input: a set with invalid content is skipped and named in the output, the other sets of that user and all other users are processed normally.
- **Parallel runs.** Only the HKLM remediation and the HKCU merge remediation take the global mutex `Global\EdgeManagedFavoritesMerge`. The HKCU set pair does not take it, each set remediation only writes its own key in the profile of the signed-in user.
- **Dynamic refresh.** Edge picks up the new policy without a restart. Check `edge://policy` if favorites do not show up.
- **Folder names.** When the same folder is written in different upper/lower case in several sets, the spelling of the set that comes first by `SetName` is used.
- **Devices or users that were away for a long time.** HKLM: if a device was off for longer than `$StaleAfterDays`, the first favorites remediation that runs removes all other sets as stale. HKCU: if a user did not sign in for longer than `$StaleAfterDays`, the merge remediation removes the sets of that user after the next sign-in. The sets come back as soon as their set remediations run again.
- **Detection compares case-sensitive.** A URL or name change in upper/lower case only is detected and deployed.
- **HKCU variant and signed-out users.** The merge remediation only updates loaded user profiles. A user who is not signed in keeps the last value in the own profile and gets the current favorites on the first merge run after the next sign-in.
- **Removal.** Unassigning a remediation removes its favorites after `$StaleAfterDays` days. HKLM: the next time another favorites remediation runs. When the last remediation is gone, run one remediation with `$RemoveSet = $true` first, or delete the policy value `ManagedFavorites` and the `$RegistryBasePath` key manually. HKCU: the merge remediation removes stale sets of every user and the policy value of users without sets. Keep the merge remediation assigned until the stale sets are gone.

## 🛠️ Troubleshooting

| Symptom | Check |
|---|---|
| Favorites do not show up | `edge://policy`: is `ManagedFavorites` there, with the expected "Applies to"? Does another profile, GPO or script set `ManagedFavorites`? |
| HKCU favorites missing although the set remediation ran | The merge remediation is assigned to the device and has run since (hourly). The merge output may name the set as invalid or incomplete |
| HKCU favorites missing on some devices | The device also gets the HKLM variant or another device policy for `ManagedFavorites`. The device policy wins |
| Set remediation fails with `The script runs as SYSTEM` | Set **Run this script using the logged-on credentials** to Yes for the set pair |
| Scripts fail with `RefreshAfterDays (...) must be at least 1 and lower than StaleAfterDays` | Fix `$RefreshAfterDays` and `$StaleAfterDays` in the Parameters block of both scripts |
| Remediation fails with `Timeout waiting for another favorites remediation to finish.` | Another HKLM or merge remediation held the mutex for more than 2 minutes. The next scheduled run tries again |
| Root folder name differs between devices or users | `$TopLevelName` is not identical in every remediation |

## 👤 Author

**Daniel Fraubaum**  
Blog: [headsinthecloud.blog](https://headsinthecloud.blog)  
LinkedIn: [daniel-fraubaum](https://www.linkedin.com/in/daniel-fraubaum-b352ba1aa/)

Use at your own risk. Test in a pilot group before rolling out broadly.
