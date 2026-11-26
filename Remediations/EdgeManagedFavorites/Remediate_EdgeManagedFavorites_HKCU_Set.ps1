<#
    Script:      Remediate_EdgeManagedFavorites_HKCU_Set.ps1
    Author:      Daniel Fraubaum
    Blog:        https://headsinthecloud.blog
    Version:     1.4
    Date:        2026-11-26
    Description: Writes or removes the favorites set of this remediation in the staging key of the
                 signed-in user (HKCU). Runs with the logged-on credentials, so every user only gets
                 the sets of the remediations assigned to them. The Edge ManagedFavorites user policy
                 is built from these sets by the merge remediation (EdgeManagedFavorites_HKCU_Merge_*),
                 which must be assigned as well.
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

# Unique name of this favorites set. Use a different value in every set remediation you assign.
$SetName = "General"

# Name of the managed favorites root folder in Edge. Empty = Edge default "Managed favorites".
# Must be identical in every set remediation. If the values differ, the set that comes
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

# $true = remove this set from the profile of the signed-in user.
$RemoveSet = $false

# Staging location of the sets, relative to the profile of the signed-in user (HKCU).
# Must be identical in every set remediation and in the merge remediation.
$RegistryBasePath = "Software\CompanyName\EdgeManagedFavorites"

# The merge remediation removes sets not refreshed for this many days (0 = never).
# Must be identical in every set remediation and in the merge remediation.
$StaleAfterDays = 30

# Detection requests a refresh of the set timestamp after this many days (0 = never).
$RefreshAfterDays = 7

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
    if ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq "S-1-5-18") {
        throw "The script runs as SYSTEM. Set ""Run this script using the logged-on credentials"" to Yes, otherwise the set ends up in the profile of SYSTEM."
    }
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name -match "[\\/*?\[\]]") {
        throw "Invalid SetName ""$Name"". It must not be empty or contain \ / * ? [ ]."
    }
    if ([string]::IsNullOrWhiteSpace($BasePath) -or $BasePath -match "^(HK|Registry)|:|^\\|[*?\[\]]") {
        throw "Invalid RegistryBasePath ""$BasePath"". It must be relative to the user profile, for example Software\CompanyName\EdgeManagedFavorites."
    }
    if ($StaleDays -gt 0 -and ($RefreshDays -le 0 -or $RefreshDays -ge $StaleDays)) {
        throw "RefreshAfterDays ($RefreshDays) must be at least 1 and lower than StaleAfterDays ($StaleDays), otherwise the merge remediation removes this set as stale."
    }
}

function Get-RegistryValue {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $Property = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $Property) { return $null }
    return $Property.$Name
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

# ==========================================================================================
# Logic
# ==========================================================================================

try {
    # Step 1: Build the desired state of this set
    Assert-Configuration -Name $SetName -BasePath $RegistryBasePath -StaleDays $StaleAfterDays -RefreshDays $RefreshAfterDays
    $OwnSetPath = Join-Path -Path "HKCU:\$RegistryBasePath" -ChildPath "Sets\$SetName"
    $DesiredSetJson = ConvertTo-SetJson -Items $Favorites
    $User = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

    # Step 2: Write or remove this set in the staging key of the signed-in user
    if ($RemoveSet) {
        if (Test-Path -LiteralPath $OwnSetPath) { Remove-Item -LiteralPath $OwnSetPath -Recurse -Force -ErrorAction Stop }
        $Message = "Set ""$SetName"" removed for $User."
    }
    else {
        if (-not (Test-Path -LiteralPath $OwnSetPath)) { New-Item -Path $OwnSetPath -Force -ErrorAction Stop | Out-Null }
        New-ItemProperty -LiteralPath $OwnSetPath -Name "Favorites" -Value $DesiredSetJson -PropertyType String -Force -ErrorAction Stop | Out-Null
        New-ItemProperty -LiteralPath $OwnSetPath -Name "TopLevelName" -Value "$TopLevelName" -PropertyType String -Force -ErrorAction Stop | Out-Null
        # LastUpdated comes last: the merge remediation skips a set without a valid timestamp, so a new set is only merged when it is complete
        New-ItemProperty -LiteralPath $OwnSetPath -Name "LastUpdated" -Value (Get-Date).ToUniversalTime().ToString("o") -PropertyType String -Force -ErrorAction Stop | Out-Null
        $Message = "Set ""$SetName"" written for $User."
    }

    # Step 3: Report
    Write-Output "$Message The merge remediation applies it to Edge on its next run."
    exit 0
}
catch {
    Write-Error "Remediation failed: $($_.Exception.Message)"
    exit 1
}
