<#
    Script:      EdgeManagedFavorites_HKLM_Remediate.ps1
    Author:      Daniel Fraubaum
    Version:     1.2
    Date:        2026-11-24
    Description: Writes the favorites set of this remediation to a staging key and rebuilds the
                 Microsoft Edge ManagedFavorites policy (HKLM) from all sets on the device.
                 Several remediations with different SetName values are merged into one
                 alphabetically sorted favorites tree (folders first, then links).
                 Keep the Parameters section identical in the Detect and Remediate script.
                 Do not combine with the HKCU variant on the same device.
#>

# ==========================================================================================
# Parameters
# ==========================================================================================

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
$RegistryBasePath = "HKLM:\SOFTWARE\YourCompany\EdgeManagedFavorites"

# Sets not refreshed for this many days are ignored and cleaned up (0 = never).
$StaleAfterDays = 30

# Detection requests a refresh of the set timestamp after this many days (0 = never).
$RefreshAfterDays = 7

# Edge policy target
$EdgePolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
$EdgePolicyName = "ManagedFavorites"

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
    param([string]$Name, [int]$StaleDays, [int]$RefreshDays)
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
    foreach ($Key in Get-ChildItem -Path $SetsPath) {
        $Properties = Get-ItemProperty -Path $Key.PSPath
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

$Mutex = $null
$HasMutex = $false
try {
    # Step 1: Serialize parallel runs of several favorites remediations
    $Mutex = New-Object System.Threading.Mutex($false, "Global\EdgeManagedFavoritesMerge")
    try { $HasMutex = $Mutex.WaitOne(120000) }
    catch [System.Threading.AbandonedMutexException] {
        # A previous run was terminated while holding the mutex. The mutex is now owned by this run.
        $HasMutex = $true
    }
    if (-not $HasMutex) { throw "Timeout waiting for another favorites remediation to finish." }

    # Step 2: Build the desired state of this set
    Assert-Configuration -Name $SetName -StaleDays $StaleAfterDays -RefreshDays $RefreshAfterDays
    $SetsPath = Join-Path -Path $RegistryBasePath -ChildPath "Sets"
    $OwnSetPath = Join-Path -Path $SetsPath -ChildPath $SetName
    $DesiredSetJson = ConvertTo-SetJson -Items $Favorites

    # Step 3: Write or remove this set in the staging key
    if ($RemoveSet) {
        if (Test-Path -Path $OwnSetPath) { Remove-Item -Path $OwnSetPath -Recurse -Force }
    }
    else {
        if (-not (Test-Path -Path $OwnSetPath)) { New-Item -Path $OwnSetPath -Force | Out-Null }
        New-ItemProperty -Path $OwnSetPath -Name "Favorites" -Value $DesiredSetJson -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $OwnSetPath -Name "TopLevelName" -Value "$TopLevelName" -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $OwnSetPath -Name "LastUpdated" -Value (Get-Date).ToUniversalTime().ToString("o") -PropertyType String -Force | Out-Null
    }

    # Step 4: Clean up stale sets of remediations that are no longer assigned
    $RemovedSets = New-Object System.Collections.ArrayList
    foreach ($Set in (Get-StoredSets -SetsPath $SetsPath)) {
        if ($Set.Name -eq $SetName) { continue }
        if (Test-IsStale -LastUpdated $Set.LastUpdated -Days $StaleAfterDays) {
            Remove-Item -Path (Join-Path -Path $SetsPath -ChildPath $Set.Name) -Recurse -Force
            [void]$RemovedSets.Add($Set.Name)
        }
    }

    # Step 5: Merge all sets into the Edge policy JSON
    $StoredSets = Get-StoredSets -SetsPath $SetsPath
    $EffectiveSets = Get-EffectiveSets -StoredSets $StoredSets -OwnName $SetName -OwnJson $DesiredSetJson -OwnTopLevelName $TopLevelName -RemoveOwn $RemoveSet -StaleDays $StaleAfterDays
    $PolicyJson = Build-ManagedFavoritesJson -Sets $EffectiveSets

    # Step 6: Write or remove the Edge policy value (never recreate the existing policy key)
    if ($PolicyJson) {
        if (-not (Test-Path -Path $EdgePolicyPath)) { New-Item -Path $EdgePolicyPath -Force | Out-Null }
        New-ItemProperty -Path $EdgePolicyPath -Name $EdgePolicyName -Value $PolicyJson -PropertyType String -Force | Out-Null
    }
    elseif ($null -ne (Get-RegistryValue -Path $EdgePolicyPath -Name $EdgePolicyName)) {
        Remove-ItemProperty -Path $EdgePolicyPath -Name $EdgePolicyName -Force
    }

    # Step 7: Report
    $SetNames = (@($EffectiveSets | ForEach-Object { $_.Name }) -join ", ")
    $Action = if ($RemoveSet) { "removed" } else { "written" }
    $Message = "Set ""$SetName"" $Action. Merged sets: $SetNames."
    if ($RemovedSets.Count -gt 0) { $Message += " Stale sets removed: $($RemovedSets -join ", ")." }
    if (-not $PolicyJson) { $Message += " No favorites left, policy value removed." }
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
