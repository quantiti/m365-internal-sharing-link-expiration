[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ConfigPath,

    [switch]$Apply
)

$ErrorActionPreference = "Stop"

. "$PSScriptRoot/Policy.Common.ps1"

$config = Read-PolicyConfig -Path $ConfigPath

if ($config.State.Backend -ne "File") {
    throw "This script currently supports State.Backend='File'."
}

$adminUrl = [string]$config.Tenant.AdminUrl
$groupId = [string]$config.GroupPolicy.GroupId
$statePath = [string]$config.State.FilePath
$logDirectory = [string]$config.Logging.Directory

Connect-M365PolicyServices -AdminUrl $adminUrl

$state = Get-ManagedState -Path $statePath -GroupId $groupId
$results = [System.Collections.Generic.List[object]]::new()

foreach ($entry in @($state.Sites)) {
    try {
        if (-not $Apply) {
            $results.Add([pscustomobject]@{
                TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
                Action       = "RestoreTenantInheritance"
                Status       = "WouldChange"
                User         = [string]$entry.User
                SiteUrl      = [string]$entry.Url
                Detail       = "Would disable organization-link expiration override."
            })
            continue
        }

        Set-SPOSite `
            -Identity ([string]$entry.Url) `
            -OverrideTenantOrganizationSharingLinkExpirationPolicy $false

        $results.Add([pscustomobject]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
            Action       = "RestoreTenantInheritance"
            Status       = "Applied"
            User         = [string]$entry.User
            SiteUrl      = [string]$entry.Url
            Detail       = "Tenant inheritance restored."
        })
    }
    catch {
        $results.Add([pscustomobject]@{
            TimestampUtc = (Get-Date).ToUniversalTime().ToString("o")
            Action       = "RestoreTenantInheritance"
            Status       = "Error"
            User         = [string]$entry.User
            SiteUrl      = [string]$entry.Url
            Detail       = $_.Exception.Message
        })
    }
}

Write-OperationLog `
    -Results $results `
    -Directory $logDirectory `
    -Prefix "RestoreManagedSites" | Out-Null

$results | Format-Table -AutoSize

if ($Apply) {
    $failed = @($results | Where-Object { $_.Status -eq "Error" })

    if ($failed.Count -eq 0) {
        $emptyState = [pscustomobject]@{
            Version              = 1
            GroupId              = $groupId
            LastSuccessfulRunUtc = (Get-Date).ToUniversalTime().ToString("o")
            Sites                = @()
        }
        Save-ManagedState -State $emptyState -Path $statePath
        Write-Host "All managed sites restored. State cleared."
    }
    else {
        Write-Warning "$($failed.Count) site(s) failed rollback. State was not cleared; retry after fixing errors."
    }
}
else {
    Write-Warning "DRY-RUN only."
}
