<#
    Script:      Detect_EdgeManagedFavorites_HKLM.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.6
    Date:        2026-11-26
    Description: Checks whether the favorites set of this remediation is present and current in
                 the staging key and whether the Microsoft Edge ManagedFavorites policy (HKLM)
                 matches the merged result of all sets on the device. Changes nothing.
                 Fill the Parameters block in the Detect script and copy it 1:1 into the
                 Remediate script, both scripts must always contain the same block.
                 Do not combine with the HKCU variant on the same device.
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

# Unique name of this favorites set. Use a different value in every remediation you assign.
$SetName = "General"

# Name of the managed favorites root folder in Edge. Empty = Edge default "Managed favorites".
# Must be identical in every favorites remediation. If the values differ, the set that comes
# first alphabetically (by SetName) wins.
$TopLevelName = "Company Favorites"

# Favorites of this set.
# Path = folder structure separated by "/", empty = directly in the managed favorites root.
$Favorites = @(
    @{ Path = "";                        Name = "Microsoft"; Url = "https://www.microsoft.com" }
    @{ Path = "Admin Portals";           Name = "Intune";    Url = "https://intune.microsoft.com" }
    @{ Path = "Admin Portals";           Name = "Entra";     Url = "https://entra.microsoft.com" }
    @{ Path = "Admin Portals/Security";  Name = "Defender";  Url = "https://security.microsoft.com" }
)

# $true = remove this set from the device and rebuild the policy from the remaining sets.
$RemoveSet = $false

# Staging location for all sets. Must be identical in every remediation.
$RegistryBasePath = "HKLM:\SOFTWARE\CompanyName\EdgeManagedFavorites"

# Sets not refreshed for this many days are ignored and cleaned up (0 = never).
$StaleAfterDays = 30

# Detection requests a refresh of the set timestamp after this many days (0 = never).
$RefreshAfterDays = 7

# Edge policy target
$EdgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
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

function ConvertTo-SetJson {
    param([array]$Items)
    $Normalized = New-Object System.Collections.ArrayList
    foreach ($Item in $Items) {
        if ([string]::IsNullOrWhiteSpace($Item.Name) -or [string]::IsNullOrWhiteSpace($Item.Url)) {
            throw "Favorite with empty Name or Url in set ""$SetName""."
        }
        [void]$Normalized.Add([ordered]@{
            Path = Get-NormalizedPath -Path $Item.Path
            Name = $Item.Name.Trim()
            Url  = $Item.Url.Trim()
        })
    }
    $Sorted = @($Normalized | Sort-Object { $_.Path }, { $_.Name }, { $_.Url })
    return (ConvertTo-Json -InputObject $Sorted -Depth 5 -Compress)
}

function Assert-Configuration {
    param([string]$Name, [string]$BasePath, [int]$StaleDays, [int]$RefreshDays)
    if (-not [Environment]::Is64BitProcess) {
        throw "The script runs in 32-bit PowerShell. Set ""Run script in 64-bit PowerShell"" to Yes, otherwise the set ends up under WOW6432Node while the Edge policy key is shared, and several remediations overwrite each other."
    }
    if ($BasePath -notmatch "^HKLM:\\SOFTWARE\\[^*?\[\]]+$") {
        throw "Invalid RegistryBasePath ""$BasePath"". It must start with HKLM:\SOFTWARE\, for example HKLM:\SOFTWARE\CompanyName\EdgeManagedFavorites."
    }
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -match "[\\/*?\[\]]") {
        throw "Invalid SetName ""$Name"". It must not be empty or contain \ / * ? [ ]."
    }
    if ($StaleDays -gt 0 -and ($RefreshDays -le 0 -or $RefreshDays -ge $StaleDays)) {
        throw "RefreshAfterDays ($RefreshDays) must be at least 1 and lower than StaleAfterDays ($StaleDays), otherwise other remediations remove this set as stale."
    }
}

function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -Path $Path)) { return $null }
    $Property = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $Property) { return $null }
    return $Property.$Name
}

function Get-StoredSets {
    param([string]$SetsPath)
    $Result = New-Object System.Collections.ArrayList
    if (-not (Test-Path -Path $SetsPath)) { return ,$Result }
    foreach ($Key in Get-ChildItem -Path $SetsPath -ErrorAction Stop) {
        $Properties = Get-ItemProperty -Path $Key.PSPath -ErrorAction Stop
        [void]$Result.Add([pscustomobject]@{
            Name          = $Key.PSChildName
            FavoritesJson = $Properties.Favorites
            TopLevelName  = $Properties.TopLevelName
            LastUpdated   = $Properties.LastUpdated
        })
    }
    return ,$Result
}

function Test-IsStale {
    param([string]$LastUpdated, [int]$Days)
    if ($Days -le 0) { return $false }
    $Parsed = [datetime]::MinValue
    $Styles = [System.Globalization.DateTimeStyles]::RoundtripKind
    $Culture = [System.Globalization.CultureInfo]::InvariantCulture
    if (-not [datetime]::TryParse($LastUpdated, $Culture, $Styles, [ref]$Parsed)) { return $true }
    return (((Get-Date).ToUniversalTime() - $Parsed.ToUniversalTime()).TotalDays -gt $Days)
}

function Get-EffectiveSets {
    param($StoredSets, [string]$OwnName, [string]$OwnJson, [string]$OwnTopLevelName, [bool]$RemoveOwn, [int]$StaleDays)
    $Result = New-Object System.Collections.ArrayList
    foreach ($Set in $StoredSets) {
        if ($Set.Name -eq $OwnName) { continue }
        if (Test-IsStale -LastUpdated $Set.LastUpdated -Days $StaleDays) { continue }
        [void]$Result.Add($Set)
    }
    if (-not $RemoveOwn) {
        [void]$Result.Add([pscustomobject]@{
            Name          = $OwnName
            FavoritesJson = $OwnJson
            TopLevelName  = $OwnTopLevelName
            LastUpdated   = ""
        })
    }
    return ,@($Result | Sort-Object -Property Name)
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
        if ([string]::IsNullOrWhiteSpace($Set.FavoritesJson)) { continue }

        foreach ($Item in (ConvertFrom-Json -InputObject $Set.FavoritesJson)) {
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

# ==========================================================================================
# Logic
# ==========================================================================================

try {
    # Step 1: Build the desired state of this set
    Assert-Configuration -Name $SetName -BasePath $RegistryBasePath -StaleDays $StaleAfterDays -RefreshDays $RefreshAfterDays
    $SetsPath = Join-Path -Path $RegistryBasePath -ChildPath "Sets"
    $DesiredSetJson = ConvertTo-SetJson -Items $Favorites
    $StoredSets = Get-StoredSets -SetsPath $SetsPath
    $OwnStored = $StoredSets | Where-Object { $_.Name -eq $SetName } | Select-Object -First 1
    $Issues = New-Object System.Collections.ArrayList

    # Step 2: Check this set in the staging key
    if ($RemoveSet) {
        if ($OwnStored) { [void]$Issues.Add("set ""$SetName"" still present but marked for removal") }
    }
    elseif (-not $OwnStored) {
        [void]$Issues.Add("set ""$SetName"" missing")
    }
    else {
        if ("$($OwnStored.FavoritesJson)" -cne $DesiredSetJson) { [void]$Issues.Add("favorites of set ""$SetName"" changed") }
        if ("$($OwnStored.TopLevelName)" -cne "$TopLevelName") { [void]$Issues.Add("top level name of set ""$SetName"" changed") }
        if (Test-IsStale -LastUpdated $OwnStored.LastUpdated -Days $RefreshAfterDays) { [void]$Issues.Add("set ""$SetName"" refresh due") }
    }

    # Step 3: Check for stale sets waiting for cleanup
    foreach ($Set in $StoredSets) {
        if ($Set.Name -eq $SetName) { continue }
        if (Test-IsStale -LastUpdated $Set.LastUpdated -Days $StaleAfterDays) { [void]$Issues.Add("stale set ""$($Set.Name)"" pending cleanup") }
    }

    # Step 4: Compare the merged result with the current Edge policy
    $EffectiveSets = Get-EffectiveSets -StoredSets $StoredSets -OwnName $SetName -OwnJson $DesiredSetJson -OwnTopLevelName $TopLevelName -RemoveOwn $RemoveSet -StaleDays $StaleAfterDays
    $DesiredPolicyJson = Build-ManagedFavoritesJson -Sets $EffectiveSets
    $CurrentPolicyJson = Get-RegistryValue -Path $EdgePolicyPath -Name $EdgePolicyName
    if ("$CurrentPolicyJson" -cne "$DesiredPolicyJson") { [void]$Issues.Add("Edge ManagedFavorites policy differs from merged result") }

    # Step 5: Report
    if ($Issues.Count -gt 0) {
        Write-Output "Not compliant: $($Issues -join "; ")."
        exit 1
    }
    $OwnState = if ($RemoveSet) { "not present" } else { "current" }
    Write-Output "Compliant: set ""$SetName"" $OwnState, merged sets: $(@($EffectiveSets | ForEach-Object { $_.Name }) -join ", ")."
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
