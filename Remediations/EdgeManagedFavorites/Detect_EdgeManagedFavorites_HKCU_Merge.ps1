<#
    Script:      Detect_EdgeManagedFavorites_HKCU_Merge.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.4
    Date:        2026-11-26
    Description: Checks the Microsoft Edge ManagedFavorites user policy of every loaded user profile
                 against the favorites sets in the staging key of that profile. Every user only gets
                 the sets that the set remediations (EdgeManagedFavorites_HKCU_Set_*) wrote for them.
                 Runs as SYSTEM, because users cannot write to HKCU\Software\Policies.
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
$RegistryBasePath = "Software\YourCompany\EdgeManagedFavorites"

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

try {
    # Step 1: Check the configuration
    Assert-Configuration -BasePath $RegistryBasePath -PolicyPath $EdgePolicyPath -StaleDays $StaleAfterDays
    $Issues = New-Object System.Collections.ArrayList
    $Notes = New-Object System.Collections.ArrayList
    $Profiles = New-Object System.Collections.ArrayList

    # Step 2: Compare the merged sets of every loaded user profile with the Edge policy of that profile
    $UserHives = Get-UserHives
    foreach ($Hive in $UserHives) {
        try {
            $SetsPath = Join-Path -Path (Join-Path -Path $Hive.Path -ChildPath $RegistryBasePath) -ChildPath "Sets"
            $UserSets = Get-UserSets -SetsPath $SetsPath -StaleDays $StaleAfterDays
            foreach ($Name in $UserSets.Stale) { [void]$Issues.Add("stale set ""$Name"" of $($Hive.Account) pending cleanup") }
            foreach ($Entry in $UserSets.Invalid) { [void]$Notes.Add("invalid set $Entry of $($Hive.Account) skipped") }
            foreach ($Name in $UserSets.Incomplete) { [void]$Notes.Add("incomplete set ""$Name"" of $($Hive.Account) skipped") }
            $DesiredPolicyJson = Build-ManagedFavoritesJson -Sets $UserSets.Valid
            $CurrentPolicyJson = Get-RegistryValue -Path (Join-Path -Path $Hive.Path -ChildPath $EdgePolicyPath) -Name $EdgePolicyName
            if ("$CurrentPolicyJson" -cne "$DesiredPolicyJson") { [void]$Issues.Add("Edge ManagedFavorites policy of $($Hive.Account) differs from its sets") }
            $SetNames = if ($UserSets.Valid.Count -gt 0) { @($UserSets.Valid | ForEach-Object { $_.Name }) -join ", " } else { "no sets" }
            [void]$Profiles.Add("$($Hive.Account) ($SetNames)")
        }
        catch {
            [void]$Issues.Add("$($Hive.Account) could not be checked ($($_.Exception.Message))")
        }
    }

    # Step 3: Report
    $NoteText = if ($Notes.Count -gt 0) { " Notes: $($Notes -join "; ")." } else { "" }
    if ($Issues.Count -gt 0) {
        Write-Output "Not compliant: $($Issues -join "; ").$NoteText"
        exit 1
    }
    if ($UserHives.Count -eq 0) { Write-Output "Compliant: no user profile loaded.$NoteText" }
    else { Write-Output "Compliant: user profiles: $($Profiles -join ", ").$NoteText" }
    exit 0
}
catch {
    Write-Error "Detection failed: $($_.Exception.Message)"
    exit 1
}
