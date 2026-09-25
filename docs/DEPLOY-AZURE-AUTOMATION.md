# Deploy bằng Azure Automation / Managed Identity

## 1. Mục tiêu

Dùng Azure Automation để reconcile membership theo lịch mà không lưu username/password.

Kiến trúc khuyến nghị:

```text
HR / Entra attributes
        |
        v
Entra Security/Dynamic Group
        |
        v
Azure Automation Account
(System/User Assigned Managed Identity)
        |
        +--> Microsoft Graph: đọc group members
        |
        +--> SharePoint Online: đọc/ghi personal site policy
        |
        +--> Persistent state store (Azure Blob/Table)
        |
        v
Logs / Alert
```

## 2. Module cần import

Trong Automation Account, import phiên bản đã kiểm thử của:

- `Microsoft.Online.SharePoint.PowerShell`
- `Microsoft.Graph.Authentication`
- `Microsoft.Graph.Groups`

Không tự động update module production mà không test trước.

## 3. Managed Identity

SharePoint Online Management Shell hiện hỗ trợ:

```powershell
Connect-SPOService `
  -Url "https://contoso-admin.sharepoint.com" `
  -ManagedIdentity
```

User-assigned MI:

```powershell
Connect-SPOService `
  -Url "https://contoso-admin.sharepoint.com" `
  -ManagedIdentity `
  -ManagedIdentityType UserAssigned `
  -ManagedIdentityClientId "<client-id>"
```

Graph:

```powershell
Connect-MgGraph -Identity -NoWelcome
```

hoặc user-assigned:

```powershell
Connect-MgGraph `
  -Identity `
  -ClientId "<client-id>" `
  -NoWelcome
```

## 4. Quyền

Tách hai loại quyền:

### Microsoft Graph

Managed identity cần application permission đủ để đọc group membership. Ưu tiên quyền tối thiểu đáp ứng use case; thông dụng là:

- `GroupMember.Read.All`

Nếu cần đọc thêm user properties ngoài dữ liệu trả về từ member cast, đánh giá `User.Read.All`.

Application permission phải được admin consent/assign cho service principal của managed identity.

### SharePoint Online

Managed identity/service principal phải có quyền phù hợp để chạy SharePoint Online administrative cmdlet trên tenant. Trong môi trường doanh nghiệp, hãy phê duyệt qua quy trình IAM/PAM và tránh cấp Global Administrator.

## 5. State store là bắt buộc nếu muốn rollback member rời group

Không nên suy luận "site nào thuộc automation" chỉ từ `Override=true`.

Persistent state cần lưu tối thiểu:

```json
{
  "Version": 1,
  "GroupId": "...",
  "LastSuccessfulRunUtc": "...",
  "Sites": [
    {
      "User": "user@contoso.com",
      "Url": "https://contoso-my.sharepoint.com/personal/...",
      "ManagedSinceUtc": "..."
    }
  ]
}
```

Khuyến nghị production:

- Azure Blob Storage private container; hoặc
- Azure Table/Cosmos Table nếu cần query/audit tốt hơn.

Managed identity chỉ cần quyền data-plane tối thiểu trên đúng container/table.

## 6. Lịch chạy

Khuyến nghị:

- 1 lần/ngày nếu thay đổi nhân sự không cần phản ánh tức thời.
- 2–4 lần/ngày nếu onboarding/offboarding cần policy nhanh hơn.

Không cần chạy theo phút: policy này là governance control, không phải real-time security enforcement.

## 7. Alert

Alert khi:

- bất kỳ `Error`;
- số `MissingPersonalSite` tăng bất thường;
- group member count giảm/tăng vượt ngưỡng;
- state file không đọc/ghi được;
- runbook không chạy theo lịch.

## 8. Change management

Trước khi nâng version module Microsoft:

1. Clone Automation Account test hoặc dùng sandbox.
2. Chạy baseline.
3. Dry-run.
4. Pilot vài account.
5. So sánh output cmdlet.
6. Mới promote sang production.
