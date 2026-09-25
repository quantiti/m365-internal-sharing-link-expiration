[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AdminUrl,

    [Parameter(Mandatory)]
    [string]$SiteUrl,

    [int]$RecommendedDays = 30,

    [int]$MaxDays = 180,

    [switch]$InheritTenant,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Policy.Common.ps1"

if (-not $InheritTenant) {
    Assert-ExpirationPolicy `
        -RecommendedDays $RecommendedDays `
        -MaxDays $MaxDays
}

Connect-M365PolicyServices -AdminUrl $AdminUrl

$before = Get-SPOSite -Identity $SiteUrl

Write-Host "Current:"
$before | Select-Object `
    Url,
    Owner,
    OverrideTenantOrganizationSharingLinkExpirationPolicy,
    OrganizationSharingLinkRecommendedExpirationInDays,
    OrganizationSharingLinkMaxExpirationInDays | Format-List

if (-not $Apply) {
    if ($InheritTenant) {
        Write-Warning "DRY-RUN: would set site to inherit tenant organization-link expiration policy."
    }
    else {
        Write-Warning "DRY-RUN: would set Recommended=$RecommendedDays, Max=$MaxDays with tenant override enabled."
    }
    return
}

if ($InheritTenant) {
    Set-SPOSite `
        -Identity $SiteUrl `
        -OverrideTenantOrganizationSharingLinkExpirationPolicy $false
}
else {
    Set-SPOSite `
        -Identity $SiteUrl `
        -OverrideTenantOrganizationSharingLinkExpirationPolicy $true `
        -OrganizationSharingLinkRecommendedExpirationInDays $RecommendedDays `
        -OrganizationSharingLinkMaxExpirationInDays $MaxDays
}

$after = Get-SPOSite -Identity $SiteUrl

Write-Host "After:"
$after | Select-Object `
    Url,
    Owner,
    OverrideTenantOrganizationSharingLinkExpirationPolicy,
    OrganizationSharingLinkRecommendedExpirationInDays,
    OrganizationSharingLinkMaxExpirationInDays | Format-List
