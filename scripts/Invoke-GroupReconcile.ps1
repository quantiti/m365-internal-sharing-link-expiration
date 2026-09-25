[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [switch]$Apply,

    [switch]$ManagedIdentity,

    [string]$ManagedIdentityClientId
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Policy.Common.ps1"

$config = Read-PolicyConfig -Path $ConfigPath

$adminUrl = [string]$config.Tenant.AdminUrl
$groupId = [string]$config.GroupPolicy.GroupId
$recommendedDays = [int]$config.GroupPolicy.RecommendedDays
$maxDays = [int]$config.GroupPolicy.MaxDays
$includeDisabled = [bool]$config.GroupPolicy.IncludeDisabledUsers

if ($config.State.Backend -ne "File") {
    throw "This script currently supports State.Backend='File'. Use the Azure Automation runbook for persistent Azure Blob state."
}

$statePath = [string]$config.State.FilePath
$logDirectory = [string]$config.Logging.Directory

Connect-M365PolicyServices `
    -AdminUrl $adminUrl `
    -ManagedIdentity:$ManagedIdentity `
    -ManagedIdentityClientId $ManagedIdentityClientId

Write-Host "Loading Entra group members..."
$users = Get-TargetGroupUsers `
    -GroupId $groupId `
    -IncludeDisabledUsers $includeDisabled

Write-Host "Group user count: $($users.Count)"

Write-Host "Loading OneDrive personal sites..."
$siteMap = Get-PersonalSiteMap
Write-Host "Personal site count: $($siteMap.Count)"

$state = Get-ManagedState -Path $statePath -GroupId $groupId

$previousByUrl = @{}
foreach ($entry in @($state.Sites)) {
    $previousByUrl[[string]$entry.Url] = $entry
}

$targetByUrl = @{}
$results = [System.Collections.Generic.List[object]]::new()

foreach ($user in $users) {
    $upn = ([string]$user.UserPrincipalName).Trim().ToLowerInvariant()

    if (-not $siteMap.ContainsKey($upn)) {
        $results.Add([pscustomobject]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
            Action       = "MissingPersonalSite"
            Status       = "Skipped"
            User         = $user.UserPrincipalName
            SiteUrl      = $null
            Detail       = "No provisioned personal OneDrive site was found."
        })
        continue
    }

    $site = $siteMap[$upn]
    $targetByUrl[[string]$site.Url] = [pscustomobject]@{
        User = [string]$user.UserPrincipalName
        Site = $site
    }
}

# Enforce target users.
foreach ($url in @($targetByUrl.Keys | Sort-Object)) {
    $target = $targetByUrl[$url]
    $userUpn = $target.User

    try {
        # Re-read the individual site so we compare the effective current values.
        $site = Get-SPOSite -Identity $url

        if (Test-SitePolicyMatches `
            -Site $site `
            -RecommendedDays $recommendedDays `
            -MaxDays $maxDays) {

            $results.Add([pscustomobject]@{
                TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
                Action       = "Enforce"
                Status       = "Unchanged"
                User         = $userUpn
                SiteUrl      = $url
                Detail       = "Policy already matches desired state."
            })
            continue
        }

        if (-not $Apply) {
            $results.Add([pscustomobject]@{
                TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
                Action       = "Enforce"
                Status       = "WouldChange"
                User         = $userUpn
                SiteUrl      = $url
                Detail       = "Would set Recommended=$recommendedDays, Max=$maxDays, Override=true."
            })
            continue
        }

        Set-SPOSite `
            -Identity $url `
            -OverrideTenantOrganizationSharingLinkExpirationPolicy $true `
            -OrganizationSharingLinkRecommendedExpirationInDays $recommendedDays `
            -OrganizationSharingLinkMaxExpirationInDays $maxDays

        $verify = Get-SPOSite -Identity $url

        if (-not (Test-SitePolicyMatches `
            -Site $verify `
            -RecommendedDays $recommendedDays `
            -MaxDays $maxDays)) {
            throw "Post-change verification failed."
        }

        $results.Add([pscustomobject]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
            Action       = "Enforce"
            Status       = "Applied"
            User         = $userUpn
            SiteUrl      = $url
            Detail       = "Recommended=$recommendedDays, Max=$maxDays, Override=true."
        })
    }
    catch {
        $results.Add([pscustomobject]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
            Action       = "Enforce"
            Status       = "Error"
            User         = $userUpn
            SiteUrl      = $url
            Detail       = $_.Exception.Message
        })
    }
}

# Roll back ONLY sites that this automation previously managed and are no longer targets.
$removedUrls = @(
    $previousByUrl.Keys |
    Where-Object { -not $targetByUrl.ContainsKey($_) } |
    Sort-Object
)

foreach ($url in $removedUrls) {
    $entry = $previousByUrl[$url]

    try {
        if (-not $Apply) {
            $results.Add([pscustomobject]@{
                TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
                Action       = "Rollback"
                Status       = "WouldChange"
                User         = [string]$entry.User
                SiteUrl      = $url
                Detail       = "Would disable site override and return to tenant inheritance."
            })
            continue
        }

        Set-SPOSite `
            -Identity $url `
            -OverrideTenantOrganizationSharingLinkExpirationPolicy $false

        $verify = Get-SPOSite -Identity $url

        if ([bool]$verify.OverrideTenantOrganizationSharingLinkExpirationPolicy -eq $true) {
            throw "Post-rollback verification failed: override is still enabled."
        }

        $results.Add([pscustomobject]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
            Action       = "Rollback"
            Status       = "Applied"
            User         = [string]$entry.User
            SiteUrl      = $url
            Detail       = "Returned to tenant policy inheritance."
        })
    }
    catch {
        $results.Add([pscustomobject]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
            Action       = "Rollback"
            Status       = "Error"
            User         = [string]$entry.User
            SiteUrl      = $url
            Detail       = $_.Exception.Message
        })
    }
}

Write-OperationLog `
    -Results $results `
    -Directory $logDirectory `
    -Prefix "GroupReconcile" | Out-Null

$results | Sort-Object Action, Status, User | Format-Table -AutoSize

if ($Apply) {
    # Build next state. Keep:
    # - every current target that was successfully applied/unchanged
    # - every removed target whose rollback failed, so it can be retried
    $successfulTargetUrls = @{}

    foreach ($result in $results) {
        if (
            $result.Action -eq "Enforce" -and
            ($result.Status -eq "Applied" -or $result.Status -eq "Unchanged")
        ) {
            $successfulTargetUrls[[string]$result.SiteUrl] = $true
        }
    }

    $nextSites = [System.Collections.Generic.List[object]]::new()

    foreach ($url in $successfulTargetUrls.Keys) {
        $target = $targetByUrl[$url]

        $managedSince = (Get-Date).ToUniversalTime().ToString("o")
        if ($previousByUrl.ContainsKey($url) -and $previousByUrl[$url].ManagedSinceUtc) {
            $managedSince = [string]$previousByUrl[$url].ManagedSinceUtc
        }

        $nextSites.Add([pscustomobject]@{
            User            = $target.User
            Url             = $url
            ManagedSinceUtc = $managedSince
        })
    }

    foreach ($url in $removedUrls) {
        $rollbackResult = $results |
            Where-Object { $_.Action -eq "Rollback" -and $_.SiteUrl -eq $url } |
            Select-Object -First 1

        if ($rollbackResult -and $rollbackResult.Status -eq "Error") {
            $nextSites.Add($previousByUrl[$url])
        }
    }

    $nextState = [pscustomobject]@{
        Version              = 1
        GroupId              = $groupId
        LastSuccessfulRunUtc = (Get-Date).ToUniversalTime().ToString("o")
        Sites                = @($nextSites)
    }

    Save-ManagedState -State $nextState -Path $statePath
    Write-Host "State updated: $statePath"
}
else {
    Write-Warning "DRY-RUN completed. No policy or state file was changed."
}
