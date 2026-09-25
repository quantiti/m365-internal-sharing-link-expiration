Set-StrictMode -Version Latest

function Assert-ExpirationPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [int]$RecommendedDays,

        [Parameter(Mandatory)]
        [int]$MaxDays
    )

    if ($RecommendedDays -lt 7 -or $RecommendedDays -gt 720) {
        throw "RecommendedDays must be between 7 and 720."
    }

    if ($MaxDays -lt 7 -or $MaxDays -gt 720) {
        throw "MaxDays must be between 7 and 720."
    }

    if ($RecommendedDays -gt $MaxDays) {
        throw "RecommendedDays must be less than or equal to MaxDays."
    }
}

function Read-PolicyConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolved = Resolve-Path -Path $Path -ErrorAction Stop
    $config = Get-Content -LiteralPath $resolved.Path -Raw -Encoding UTF8 | ConvertFrom-Json

    if ([string]::IsNullOrWhiteSpace([string]$config.Tenant.AdminUrl)) {
        throw "Tenant.AdminUrl is required."
    }

    if ([string]::IsNullOrWhiteSpace([string]$config.GroupPolicy.GroupId)) {
        throw "GroupPolicy.GroupId is required."
    }

    Assert-ExpirationPolicy `
        -RecommendedDays ([int]$config.GroupPolicy.RecommendedDays) `
        -MaxDays ([int]$config.GroupPolicy.MaxDays)

    return $config
}

function Ensure-Directory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Write-OperationLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[object]]$Results,

        [Parameter(Mandatory)]
        [string]$Directory,

        [string]$Prefix = "OneDriveExpiry"
    )

    Ensure-Directory -Path $Directory

    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $path = Join-Path $Directory "$Prefix-$stamp.csv"

    $Results |
        Export-Csv -Path $path -NoTypeInformation -Encoding UTF8

    Write-Host "Log: $path"
    return $path
}

function Connect-M365PolicyServices {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AdminUrl,

        [switch]$ManagedIdentity,

        [string]$ManagedIdentityClientId
    )

    Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
    Import-Module Microsoft.Graph.Groups -ErrorAction Stop

    if ($ManagedIdentity) {
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
    }
    else {
        Connect-MgGraph -Scopes "GroupMember.Read.All","User.Read.All" -NoWelcome
        Connect-SPOService -Url $AdminUrl -UseSystemBrowser $true
    }
}

function Get-TargetGroupUsers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$GroupId,

        [bool]$IncludeDisabledUsers = $true
    )

    $users = Get-MgGroupMemberAsUser `
        -GroupId $GroupId `
        -All `
        -Property "id,userPrincipalName,accountEnabled,displayName"

    if (-not $IncludeDisabledUsers) {
        $users = $users | Where-Object { $_.AccountEnabled -eq $true }
    }

    return @($users | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.UserPrincipalName)
    })
}

function Get-PersonalSiteMap {
    [CmdletBinding()]
    param()

    $sites = Get-SPOSite -IncludePersonalSite $true -Limit All |
        Where-Object { $_.Url -like "*/personal/*" }

    $map = @{}

    foreach ($site in $sites) {
        if (-not [string]::IsNullOrWhiteSpace([string]$site.Owner)) {
            $key = ([string]$site.Owner).Trim().ToLowerInvariant()

            if (-not $map.ContainsKey($key)) {
                $map[$key] = $site
            }
        }
    }

    return $map
}

function Get-ManagedState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$GroupId
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return [pscustomobject]@{
            Version = 1
            GroupId = $GroupId
            LastSuccessfulRunUtc = $null
            Sites = @()
        }
    }

    $state = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($state.GroupId -and $state.GroupId -ne $GroupId) {
        throw "State file belongs to a different GroupId. Expected '$GroupId', found '$($state.GroupId)'."
    }

    if ($null -eq $state.Sites) {
        $state | Add-Member -MemberType NoteProperty -Name Sites -Value @()
    }

    return $state
}

function Save-ManagedState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $State,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        Ensure-Directory -Path $parent
    }

    $tmp = "$Path.tmp"
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $tmp -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Test-SitePolicyMatches {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Site,

        [Parameter(Mandatory)]
        [int]$RecommendedDays,

        [Parameter(Mandatory)]
        [int]$MaxDays
    )

    return (
        [bool]$Site.OverrideTenantOrganizationSharingLinkExpirationPolicy -eq $true -and
        [int]$Site.OrganizationSharingLinkRecommendedExpirationInDays -eq $RecommendedDays -and
        [int]$Site.OrganizationSharingLinkMaxExpirationInDays -eq $MaxDays
    )
}
