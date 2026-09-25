[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AdminUrl,

    [Parameter(Mandatory)]
    [ValidateSet("OneDrive","SharePoint","Both")]
    [string]$Scope,

    [int]$RecommendedDays = 30,

    [int]$MaxDays = 180,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Policy.Common.ps1"

Assert-ExpirationPolicy `
    -RecommendedDays $RecommendedDays `
    -MaxDays $MaxDays

Connect-M365PolicyServices -AdminUrl $AdminUrl

$current = Get-SPOTenant

Write-Host "Current tenant policy:"
$current | Select-Object `
    OneDriveOrganizationSharingLinkRecommendedExpirationInDays,
    OneDriveOrganizationSharingLinkMaxExpirationInDays,
    CoreOrganizationSharingLinkRecommendedExpirationInDays,
    CoreOrganizationSharingLinkMaxExpirationInDays | Format-List

Write-Host ""
Write-Host "Requested:"
Write-Host "  Scope           : $Scope"
Write-Host "  RecommendedDays : $RecommendedDays"
Write-Host "  MaxDays         : $MaxDays"
Write-Host "  Apply           : $($Apply.IsPresent)"

if (-not $Apply) {
    Write-Warning "DRY-RUN only. No tenant setting has been changed. Re-run with -Apply to commit."
    return
}

switch ($Scope) {
    "OneDrive" {
        Set-SPOTenant `
            -OneDriveOrganizationSharingLinkRecommendedExpirationInDays $RecommendedDays `
            -OneDriveOrganizationSharingLinkMaxExpirationInDays $MaxDays
    }

    "SharePoint" {
        Set-SPOTenant `
            -CoreOrganizationSharingLinkRecommendedExpirationInDays $RecommendedDays `
            -CoreOrganizationSharingLinkMaxExpirationInDays $MaxDays
    }

    "Both" {
        Set-SPOTenant `
            -OneDriveOrganizationSharingLinkRecommendedExpirationInDays $RecommendedDays `
            -OneDriveOrganizationSharingLinkMaxExpirationInDays $MaxDays `
            -CoreOrganizationSharingLinkRecommendedExpirationInDays $RecommendedDays `
            -CoreOrganizationSharingLinkMaxExpirationInDays $MaxDays
    }
}

Write-Host "Tenant policy updated successfully."
