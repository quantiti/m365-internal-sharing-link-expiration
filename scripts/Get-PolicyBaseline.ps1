[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AdminUrl,

    [string]$OutputDirectory = "./output"
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Policy.Common.ps1"

Ensure-Directory -Path $OutputDirectory

Connect-M365PolicyServices -AdminUrl $AdminUrl

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"

$tenant = Get-SPOTenant | Select-Object `
    OneDriveOrganizationSharingLinkRecommendedExpirationInDays,
    OneDriveOrganizationSharingLinkMaxExpirationInDays,
    CoreOrganizationSharingLinkRecommendedExpirationInDays,
    CoreOrganizationSharingLinkMaxExpirationInDays,
    OneDriveDefaultShareLinkScope,
    CoreDefaultShareLinkScope,
    OneDriveDefaultShareLinkRole,
    CoreDefaultShareLinkRole

$tenantPath = Join-Path $OutputDirectory "tenant-baseline-$stamp.json"
$tenant | ConvertTo-Json -Depth 5 | Set-Content -Path $tenantPath -Encoding UTF8

$sites = Get-SPOSite -IncludePersonalSite $true -Limit All |
    Select-Object Url,
                  Owner,
                  Template,
                  SharingCapability,
                  OverrideTenantOrganizationSharingLinkExpirationPolicy,
                  OrganizationSharingLinkRecommendedExpirationInDays,
                  OrganizationSharingLinkMaxExpirationInDays

$sitePath = Join-Path $OutputDirectory "sites-baseline-$stamp.csv"
$sites | Export-Csv -Path $sitePath -NoTypeInformation -Encoding UTF8

Write-Host "Tenant baseline: $tenantPath"
Write-Host "Sites baseline : $sitePath"
