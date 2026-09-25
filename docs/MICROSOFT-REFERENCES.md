# Microsoft references

Tài liệu nên kiểm tra lại trước mỗi thay đổi lớn hoặc sau khi nâng module.

## SharePoint Online PowerShell

### Set-SPOTenant

https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant

Các tham số trọng tâm:

- `OneDriveOrganizationSharingLinkRecommendedExpirationInDays`
- `OneDriveOrganizationSharingLinkMaxExpirationInDays`
- `CoreOrganizationSharingLinkRecommendedExpirationInDays`
- `CoreOrganizationSharingLinkMaxExpirationInDays`
- `OneDriveDefaultShareLinkScope`
- `CoreDefaultShareLinkScope`

### Set-SPOSite

https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-sposite

Các tham số trọng tâm:

- `OverrideTenantOrganizationSharingLinkExpirationPolicy`
- `OrganizationSharingLinkRecommendedExpirationInDays`
- `OrganizationSharingLinkMaxExpirationInDays`
- `DefaultShareLinkScope`

### Connect-SPOService

https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/connect-sposervice

Bao gồm authentication bằng:

- Interactive/MFA
- Certificate/app identity
- System-assigned managed identity
- User-assigned managed identity

## Microsoft Graph

### List group members

https://learn.microsoft.com/en-us/graph/api/group-list-members

PowerShell SDK hỗ trợ cast user qua:

```powershell
Get-MgGroupMemberAsUser
```

### Graph PowerShell SDK

https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started

## Lưu ý quản trị tài liệu

Microsoft 365 service và PowerShell module thay đổi theo thời gian. Không dùng blog/Q&A cũ làm nguồn cuối cùng khi cmdlet reference hiện hành đã có capability mới hơn.
