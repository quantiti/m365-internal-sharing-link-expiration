# M365 Internal Sharing Link Expiration

Repo PowerShell dùng để quản trị **expiration policy cho link chia sẻ nội bộ ("People in your organization")** trên OneDrive for Business / SharePoint Online.

Mục tiêu chính:

- Đặt `Recommended expiration` để người dùng mặc định nhìn thấy ngày hết hạn thay vì `No expiration`.
- Đặt `Maximum expiration` để giới hạn thời gian sống tối đa của link.
- Hỗ trợ 3 scope:
  1. Toàn tenant.
  2. Một OneDrive / SharePoint site cụ thể.
  3. Một nhóm user / một Khối bằng **Entra Group + reconciliation automation**.
- Không thay đổi external sharing policy.
- Mọi script có thay đổi cấu hình đều **dry-run mặc định**; chỉ thay đổi PROD khi truyền `-Apply`.

> Repo này không bật external sharing, không tạo Anyone link và không thay đổi guest policy.

## Microsoft policy model

Microsoft hiện hỗ trợ expiration cho organization sharing links ở cả tenant và site level:

| Scope | OneDrive | SharePoint |
|---|---|---|
| Tenant | `OneDriveOrganizationSharingLinkRecommendedExpirationInDays` / `OneDriveOrganizationSharingLinkMaxExpirationInDays` | `CoreOrganizationSharingLinkRecommendedExpirationInDays` / `CoreOrganizationSharingLinkMaxExpirationInDays` |
| Site | `OrganizationSharingLinkRecommendedExpirationInDays` / `OrganizationSharingLinkMaxExpirationInDays` + `OverrideTenantOrganizationSharingLinkExpirationPolicy` | Tương tự |

Giá trị hợp lệ hiện tại: **7–720 ngày**; `Recommended <= Max`.

Microsoft chưa có native group scope cho organization-link expiration. Vì vậy group scope trong repo được triển khai bằng:

```text
Entra Group
   |
   v
Reconcile membership
   |
   +--> User đang trong group -> enforce site override
   |
   +--> User đã rời group -> rollback override về tenant
```

## Teams: file thực sự nằm ở đâu?

| Hành vi | Nơi lưu file | Policy cần áp |
|---|---|---|
| Teams 1:1 / group chat | OneDrive người gửi | OneDrive/personal site |
| Teams channel | SharePoint site của Team | SharePoint site / Core tenant policy |
| Share từ OneDrive | OneDrive | OneDrive |
| Share từ SharePoint | SharePoint | SharePoint |

## Cấu trúc repo

```text
.
├── README.md
├── CHANGELOG.md
├── SECURITY.md
├── config/
│   └── policy.example.json
├── docs/
│   ├── OPERATIONS.md
│   ├── DEPLOY-AZURE-AUTOMATION.md
│   └── MICROSOFT-REFERENCES.md
├── scripts/
│   ├── Policy.Common.ps1
│   ├── Install-Dependencies.ps1
│   ├── Get-PolicyBaseline.ps1
│   ├── Set-TenantPolicy.ps1
│   ├── Set-SitePolicy.ps1
│   ├── Invoke-GroupReconcile.ps1
│   └── Restore-ManagedSites.ps1
├── runbooks/
│   └── Invoke-GroupReconcile.ManagedIdentity.ps1
├── tests/
│   └── Policy.Common.Tests.ps1
└── .github/
    └── workflows/
        └── powershell-lint.yml
```

## Quick start

### 1. Cài module

```powershell
./scripts/Install-Dependencies.ps1
```

### 2. Copy config

```powershell
Copy-Item ./config/policy.example.json ./config/policy.json
```

Sửa các trường:

```json
{
  "Tenant": {
    "AdminUrl": "https://contoso-admin.sharepoint.com"
  },
  "GroupPolicy": {
    "GroupId": "00000000-0000-0000-0000-000000000000",
    "RecommendedDays": 30,
    "MaxDays": 180
  }
}
```

### 3. Chụp baseline

```powershell
./scripts/Get-PolicyBaseline.ps1 `
  -AdminUrl "https://contoso-admin.sharepoint.com" `
  -OutputDirectory "./output"
```

### 4. Dry-run group reconcile

```powershell
./scripts/Invoke-GroupReconcile.ps1 `
  -ConfigPath "./config/policy.json"
```

Không có thay đổi PROD ở bước này.

### 5. Apply

```powershell
./scripts/Invoke-GroupReconcile.ps1 `
  -ConfigPath "./config/policy.json" `
  -Apply
```

## Khuyến nghị triển khai

Pilot ban đầu:

```text
Recommended = 30 ngày
Max         = 180 ngày
```

Sau 2–4 tuần, nếu hành vi phù hợp và tổ chức muốn chuẩn hóa toàn bộ OneDrive, cân nhắc chuyển từ group automation sang tenant-wide policy để giảm complexity vận hành.

## Tài liệu chi tiết

Đọc:

- [Hướng dẫn vận hành](docs/OPERATIONS.md)
- [Azure Automation / Managed Identity](docs/DEPLOY-AZURE-AUTOMATION.md)
- [Microsoft references](docs/MICROSOFT-REFERENCES.md)

## Nguyên tắc an toàn

- Không hard-code credential.
- Không tự dựng OneDrive URL từ UPN.
- Không rollback các site mà automation chưa từng quản lý.
- Lưu log mỗi lần reconcile.
- Chạy dry-run và review output trước lần apply đầu tiên.
- Backup baseline trước rollout.
