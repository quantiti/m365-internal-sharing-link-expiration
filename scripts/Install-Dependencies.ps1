[CmdletBinding()]
param(
    [ValidateSet("CurrentUser","AllUsers")]
    [string]$Scope = "CurrentUser"
)

$ErrorActionPreference = "Stop"

$modules = @(
    "Microsoft.Online.SharePoint.PowerShell",
    "Microsoft.Graph.Authentication",
    "Microsoft.Graph.Groups"
)

foreach ($module in $modules) {
    Write-Host "Installing/updating $module ..."
    Install-Module -Name $module -Scope $Scope -Force -AllowClobber
}

Write-Host "Done."
