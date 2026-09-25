param(
    [Parameter(Mandatory=$true)]
    [string]$AdminUrl,

    [Parameter(Mandatory=$true)]
    [string]$GroupId,

    [int]$RecommendedDays = 30,

    [int]$MaxDays = 180,

    [string]$ManagedIdentityClientId = "",

    [bool]$Apply = $false
)

$ErrorActionPreference = "Stop"

Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
Import-Module Microsoft.Graph.Groups -ErrorAction Stop

if ($RecommendedDays -lt 7 -or $RecommendedDays -gt 720) {
    throw "RecommendedDays must be between 7 and 720."
}

if ($MaxDays -lt 7 -or $MaxDays -gt 720) {
    throw "MaxDays must be between 7 and 720."
}

if ($RecommendedDays -gt $MaxDays) {
    throw "RecommendedDays must be <= MaxDays."
}

if ([string]::IsNullOrWhiteSpace($ManagedIdentityClientId)) {
    Connect-MgGraph -Identity -NoWelcome
    Connect-SPOService -Url $AdminUrl -ManagedIdentity
}
else {
    Connect-MgGraph -Identity -ClientId $ManagedIdentityClientId -NoWelcome

    Connect-SPOService `
        -Url $AdminUrl `
        -ManagedIdentity `
        -ManagedIdentityType UserAssigned `
        -ManagedIdentityClientId $ManagedIdentityClientId
}

$users = @(
    Get-MgGroupMemberAsUser `
        -GroupId $GroupId `
        -All `
        -Property "id,userPrincipalName,accountEnabled,displayName" |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.UserPrincipalName) }
)

$sites = Get-SPOSite -IncludePersonalSite $true -Limit All |
    Where-Object { $_.Url -like "*/personal/*" }

$siteByOwner = @{}
foreach ($site in $sites) {
    if (-not [string]::IsNullOrWhiteSpace([string]$site.Owner)) {
        $key = ([string]$site.Owner).Trim().ToLowerInvariant()
        if (-not $siteByOwner.ContainsKey($key)) {
            $siteByOwner[$key] = $site
        }
    }
}

# NOTE:
# Runbook intentionally does NOT implement removal rollback without a persistent
# state store. For production "user leaves group" rollback, use the repository's
# stateful reconcile design and persist state to Azure Blob/Table.
#
# This runbook is safe as an ENFORCE-ONLY building block:
# - current members are enforced;
# - non-members are untouched;
# - no site override is removed.

foreach ($user in $users) {
    $upn = ([string]$user.UserPrincipalName).Trim().ToLowerInvariant()

    if (-not $siteByOwner.ContainsKey($upn)) {
        Write-Warning "No OneDrive personal site: $($user.UserPrincipalName)"
        continue
    }

    $url = [string]$siteByOwner[$upn].Url
    $site = Get-SPOSite -Identity $url

    $matches = (
        [bool]$site.OverrideTenantOrganizationSharingLinkExpirationPolicy -eq $true -and
        [int]$site.OrganizationSharingLinkRecommendedExpirationInDays -eq $RecommendedDays -and
        [int]$site.OrganizationSharingLinkMaxExpirationInDays -eq $MaxDays
    )

    if ($matches) {
        Write-Output "UNCHANGED`t$($user.UserPrincipalName)`t$url"
        continue
    }

    if (-not $Apply) {
        Write-Output "WOULD_CHANGE`t$($user.UserPrincipalName)`t$url"
        continue
    }

    Set-SPOSite `
        -Identity $url `
        -OverrideTenantOrganizationSharingLinkExpirationPolicy $true `
        -OrganizationSharingLinkRecommendedExpirationInDays $RecommendedDays `
        -OrganizationSharingLinkMaxExpirationInDays $MaxDays

    Write-Output "APPLIED`t$($user.UserPrincipalName)`t$url"
}
