<#
    Script:      Remediate_EdgeManagedFavorites_HKCU_Merge.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.6
    Date:        2026-11-26
    Description: Rebuilds the Microsoft Edge ManagedFavorites user policy of every loaded user profile
                 from the favorites sets in the staging key of that profile and removes stale sets.
                 Every user only gets the sets that the set remediations (EdgeManagedFavorites_HKCU_Set_*)
                 wrote for them. Runs as SYSTEM, because users cannot write to HKCU\Software\Policies.
                 Assign exactly one merge remediation to the devices.
                 Fill the Parameters block in the Detect script and copy it 1:1 into the
                 Remediate script, both scripts must always contain the same block.
                 Do not combine with the HKLM variant on the same device.
#>

# ==========================================================================================
# Parameters
# ==========================================================================================
# This block is identical in the Detect and the Remediate script. How to use it:
#   1. Fill in your values between PARAMETERS START and PARAMETERS END in the Detect script.
#   2. Copy everything from PARAMETERS START to PARAMETERS END 1:1 into the Remediate script
#      and replace the same block there. Do not change anything else in the scripts.
# If the two blocks differ, detection checks other values than the remediation writes.
# ==========================================================================================

# ------------------------------------ PARAMETERS START ------------------------------------

# Staging location of the sets, relative to every user profile (HKEY_USERS\<SID>).
# Must be identical to $RegistryBasePath in every set remediation.
$RegistryBasePath = "Software\CompanyName\EdgeManagedFavorites"

# Sets not refreshed for this many days are removed (0 = never).
# Must be identical to $StaleAfterDays in every set remediation.
$StaleAfterDays = 30

# Edge policy target, relative to every user profile (HKEY_USERS\<SID>)
$EdgePolicyPath = "Software\Policies\Microsoft\Edge"
$EdgePolicyName = "ManagedFavorites"

# ------------------------------------- PARAMETERS END -------------------------------------

# ==========================================================================================
# Functions
# ==========================================================================================

function Get-NormalizedPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    $Segments = @($Path -split "/" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" })
    return ($Segments -join "/")
}

function Assert-Configuration {
    param([string]$BasePath, [string]$PolicyPath, [int]$StaleDays)
    foreach ($Entry in @(@{ Name = "RegistryBasePath"; Value = $BasePath }, @{ Name = "EdgePolicyPath"; Value = $PolicyPath })) {
        if ([string]::IsNullOrWhiteSpace($Entry.Value) -or $Entry.Value -match "^(HK|Registry)|:|^\\|[*?\[\]]") {
            throw "Invalid $($Entry.Name) ""$($Entry.Value)"". It must be relative to the user profile, for example Software\Policies\Microsoft\Edge."
        }
    }
    if ($StaleDays -lt 0) { throw "StaleAfterDays ($StaleDays) must be 0 or higher." }
}

function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $Property = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $Property) { return $null }
    return $Property.$Name
}

function Get-SetAge {
    # Valid = merge the set, Stale = remove the set,
    # Incomplete = skip the set and keep it (no valid timestamp yet, for example while the set remediation writes it)
    param([string]$LastUpdated, [int]$Days)
    $Parsed = [datetime]::MinValue
    $Styles = [System.Globalization.DateTimeStyles]::RoundtripKind
    $Culture = [System.Globalization.CultureInfo]::InvariantCulture
    if (-not [datetime]::TryParse($LastUpdated, $Culture, $Styles, [ref]$Parsed)) { return "Incomplete" }
    if ($Days -gt 0 -and ((Get-Date).ToUniversalTime() - $Parsed.ToUniversalTime()).TotalDays -gt $Days) { return "Stale" }
    return "Valid"
}

function ConvertFrom-SetJson {
    # The staging key is in the user profile and can be changed by the user, so its content is checked like any input
    param([string]$Json)
    $Result = New-Object System.Collections.ArrayList
    if ([string]::IsNullOrWhiteSpace($Json)) { return ,$Result }
    $Parsed = ConvertFrom-Json -InputObject $Json -ErrorAction Stop
    foreach ($Item in @($Parsed)) {
        if ($Item -isnot [System.Management.Automation.PSCustomObject]) { throw "entry is not an object" }
        if ($Item.Name -isnot [string] -or $Item.Url -isnot [string] -or ($null -ne $Item.Path -and $Item.Path -isnot [string])) {
            throw "Path, Name and Url must be text"
        }
        if ([string]::IsNullOrWhiteSpace($Item.Name) -or [string]::IsNullOrWhiteSpace($Item.Url)) { throw "favorite with empty Name or Url" }
        [void]$Result.Add([pscustomobject]@{
            Path = Get-NormalizedPath -Path $Item.Path
            Name = $Item.Name.Trim()
            Url  = $Item.Url.Trim()
        })
    }
    return ,$Result
}

function Get-UserSets {
    # Reads the sets of one user profile, sorted by name. Sets with invalid content are skipped.
    param([string]$SetsPath, [int]$StaleDays)
    $Result = [pscustomobject]@{
        Valid      = New-Object System.Collections.ArrayList
        Stale      = New-Object System.Collections.ArrayList
        Incomplete = New-Object System.Collections.ArrayList
        Invalid    = New-Object System.Collections.ArrayList
    }
    if (-not (Test-Path -LiteralPath $SetsPath)) { return $Result }
    foreach ($Key in @(Get-ChildItem -LiteralPath $SetsPath -ErrorAction Stop | Sort-Object -Property PSChildName)) {
        $Name = $Key.PSChildName
        $Properties = Get-ItemProperty -LiteralPath $Key.PSPath -ErrorAction Stop
        $Age = Get-SetAge -LastUpdated "$($Properties.LastUpdated)" -Days $StaleDays
        if ($Age -eq "Stale") { [void]$Result.Stale.Add($Name); continue }
        if ($Age -eq "Incomplete") { [void]$Result.Incomplete.Add($Name); continue }
        try { $Items = ConvertFrom-SetJson -Json "$($Properties.Favorites)" }
        catch { [void]$Result.Invalid.Add("$Name ($($_.Exception.Message))"); continue }
        [void]$Result.Valid.Add([pscustomobject]@{
            Name         = $Name
            Items        = $Items
            TopLevelName = "$($Properties.TopLevelName)"
        })
    }
    return $Result
}

function New-FolderNode {
    param([string]$Name)
    return [pscustomobject]@{
        Name    = $Name
        Folders = @{}
        Links   = New-Object System.Collections.ArrayList
    }
}

function ConvertTo-EdgeEntries {
    param($Node)
    $Result = New-Object System.Collections.ArrayList
    foreach ($Folder in @($Node.Folders.Values | Sort-Object -Property Name)) {
        $Children = ConvertTo-EdgeEntries -Node $Folder
        [void]$Result.Add([ordered]@{ name = $Folder.Name; children = @($Children) })
    }
    foreach ($Link in @($Node.Links | Sort-Object { $_.name }, { $_.url })) {
        [void]$Result.Add($Link)
    }
    return ,$Result
}

function Build-ManagedFavoritesJson {
    param([array]$Sets)
    $Root = New-FolderNode -Name ""
    $SeenLinks = @{}
    $ResolvedTopLevelName = ""
    $LinkCount = 0

    foreach ($Set in $Sets) {
        if (-not $ResolvedTopLevelName -and -not [string]::IsNullOrWhiteSpace($Set.TopLevelName)) {
            $ResolvedTopLevelName = $Set.TopLevelName.Trim()
        }

        foreach ($Item in $Set.Items) {
            $LinkKey = ("{0}|{1}|{2}" -f $Item.Path, $Item.Name, $Item.Url).ToLowerInvariant()
            if ($SeenLinks.ContainsKey($LinkKey)) { continue }
            $SeenLinks[$LinkKey] = $true

            $Node = $Root
            if (-not [string]::IsNullOrWhiteSpace($Item.Path)) {
                foreach ($Segment in ($Item.Path -split "/")) {
                    if (-not $Node.Folders.ContainsKey($Segment)) {
                        $Node.Folders[$Segment] = New-FolderNode -Name $Segment
                    }
                    $Node = $Node.Folders[$Segment]
                }
            }
            [void]$Node.Links.Add([ordered]@{ name = $Item.Name; url = $Item.Url })
            $LinkCount++
        }
    }

    if ($LinkCount -eq 0) { return "" }

    $Entries = New-Object System.Collections.ArrayList
    if ($ResolvedTopLevelName) { [void]$Entries.Add([ordered]@{ toplevel_name = $ResolvedTopLevelName }) }
    foreach ($Entry in (ConvertTo-EdgeEntries -Node $Root)) { [void]$Entries.Add($Entry) }
    return (ConvertTo-Json -InputObject @($Entries) -Depth 50 -Compress)
}

function Get-UserHives {
    # Loaded hives of real user profiles: local and Active Directory (S-1-5-21-...) and Entra ID (S-1-12-1-...)
    $Result = New-Object System.Collections.ArrayList
    foreach ($Key in Get-ChildItem -Path "Registry::HKEY_USERS") {
        $Sid = $Key.PSChildName
        if ($Sid -notmatch "^S-1-(5-21|12-1)(-\d+)+$") { continue }
        $Account = $Sid
        try { $Account = (New-Object System.Security.Principal.SecurityIdentifier($Sid)).Translate([System.Security.Principal.NTAccount]).Value }
        catch { $Account = $Sid }
        [void]$Result.Add([pscustomobject]@{
            Sid     = $Sid
            Account = $Account
            Path    = "Registry::HKEY_USERS\$Sid"
        })
    }
    return ,$Result
}

# ==========================================================================================
# Logic
# ==========================================================================================

$Mutex = $null
$HasMutex = $false
try {
    # Step 1: Serialize parallel runs of the merge remediation
    $Mutex = New-Object System.Threading.Mutex($false, "Global\EdgeManagedFavoritesMerge")
    try { $HasMutex = $Mutex.WaitOne(120000) }
    catch [System.Threading.AbandonedMutexException] {
        # A previous run was terminated while holding the mutex. The mutex is now owned by this run.
        $HasMutex = $true
    }
    if (-not $HasMutex) { throw "Timeout waiting for another favorites remediation to finish." }

    # Step 2: Check the configuration
    Assert-Configuration -BasePath $RegistryBasePath -PolicyPath $EdgePolicyPath -StaleDays $StaleAfterDays
    $UpdatedProfiles = New-Object System.Collections.ArrayList
    $FailedProfiles = New-Object System.Collections.ArrayList
    $RemovedSets = New-Object System.Collections.ArrayList
    $Notes = New-Object System.Collections.ArrayList

    # Step 3: Per loaded user profile: remove stale sets, merge the remaining sets and write the Edge policy
    $UserHives = Get-UserHives
    foreach ($Hive in $UserHives) {
        try {
            $SetsPath = Join-Path -Path (Join-Path -Path $Hive.Path -ChildPath $RegistryBasePath) -ChildPath "Sets"
            $UserSets = Get-UserSets -SetsPath $SetsPath -StaleDays $StaleAfterDays
            foreach ($Name in $UserSets.Stale) {
                Remove-Item -LiteralPath (Join-Path -Path $SetsPath -ChildPath $Name) -Recurse -Force -ErrorAction Stop
                [void]$RemovedSets.Add("$Name ($($Hive.Account))")
            }
            foreach ($Entry in $UserSets.Invalid) { [void]$Notes.Add("invalid set $Entry of $($Hive.Account) skipped") }
            foreach ($Name in $UserSets.Incomplete) { [void]$Notes.Add("incomplete set ""$Name"" of $($Hive.Account) skipped") }

            # Never recreate an existing policy key, other Edge user policies stay untouched
            $PolicyJson = Build-ManagedFavoritesJson -Sets $UserSets.Valid
            $UserPolicyPath = Join-Path -Path $Hive.Path -ChildPath $EdgePolicyPath
            if ($PolicyJson) {
                if (-not (Test-Path -LiteralPath $UserPolicyPath)) { New-Item -Path $UserPolicyPath -Force -ErrorAction Stop | Out-Null }
                New-ItemProperty -LiteralPath $UserPolicyPath -Name $EdgePolicyName -Value $PolicyJson -PropertyType String -Force -ErrorAction Stop | Out-Null
            }
            elseif ($null -ne (Get-RegistryValue -Path $UserPolicyPath -Name $EdgePolicyName)) {
                Remove-ItemProperty -LiteralPath $UserPolicyPath -Name $EdgePolicyName -Force -ErrorAction Stop
            }
            $SetNames = if ($UserSets.Valid.Count -gt 0) { @($UserSets.Valid | ForEach-Object { $_.Name }) -join ", " } else { "no sets" }
            [void]$UpdatedProfiles.Add("$($Hive.Account) ($SetNames)")
        }
        catch {
            [void]$FailedProfiles.Add("$($Hive.Account) ($($_.Exception.Message))")
        }
    }

    # Step 4: Report
    if ($UserHives.Count -eq 0) { $Message = "No user profile loaded, the policy is written on the next run after a sign-in." }
    else { $Message = "User profiles updated: $(if ($UpdatedProfiles.Count -gt 0) { $UpdatedProfiles -join ", " } else { "none" })." }
    if ($RemovedSets.Count -gt 0) { $Message += " Stale sets removed: $($RemovedSets -join ", ")." }
    if ($Notes.Count -gt 0) { $Message += " Notes: $($Notes -join "; ")." }
    if ($FailedProfiles.Count -gt 0) { throw "$Message Failed for: $($FailedProfiles -join ", ")." }
    Write-Output $Message
    exit 0
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
finally {
    if ($null -ne $Mutex) {
        if ($HasMutex) { $Mutex.ReleaseMutex() }
        $Mutex.Dispose()
    }
}
