# HƯỚNG DẪN QUẢN TRỊ CHÍNH SÁCH CHIA SẺ NỘI BỘ VÀ HẾT HẠN LIÊN KẾT TRÊN ONEDRIVE / SHAREPOINT ONLINE

*Tài liệu vận hành môi trường Production*

| Thuộc tính | Giá trị |
| --- | --- |
| Phạm vi | Microsoft 365 - OneDrive for Business, SharePoint Online, Microsoft Teams file sharing |
| Trọng tâm | People in your organization sharing links (internal organization links) |
| Mục tiêu use case | Mặc định đặt ngày hết hạn cho link chia sẻ nội bộ; người dùng có thể thay đổi trong giới hạn do quản trị viên quy định |
| Ngày rà soát tài liệu hãng | 25/09/2026 |
| Đối tượng sử dụng | M365 / SharePoint / OneDrive Administrator; IAM/Entra Administrator; Security Operations |
| Môi trường | Production; ưu tiên least privilege, audit, dry-run, rollback và reconciliation |

> **Lưu ý:** Tuyên bố phạm vi: Tài liệu này tập trung vào link “People in your organization”. Các policy “Anyone/anonymous”, guest expiration và external sharing được giải thích để phân biệt nhưng không phải mục tiêu chính của use case.

## 1. Mục tiêu và bối cảnh vận hành

Use case điển hình: một Khối/đơn vị muốn các file được nhân sự chia sẻ nội bộ bằng link (ví dụ gửi vào Teams group chat) tự có ngày hết hạn mặc định, thay vì “No expiration”. Người dùng vẫn được phép chọn ngày khác khi nghiệp vụ yêu cầu; quản trị viên có thể đặt một giá trị tối đa để giới hạn thời gian sống của link.

Trong Microsoft 365, cần xác định đúng nơi lưu trữ file trước khi áp chính sách:

| Kênh sử dụng | Nơi lưu file | Đối tượng policy chính |
| --- | --- | --- |
| Teams 1:1 chat / group chat | OneDrive của người gửi | OneDrive organization sharing link policy |
| Teams standard/private/shared channel | SharePoint site tương ứng | SharePoint organization sharing link policy |
| Chia sẻ trực tiếp từ OneDrive web / Office | OneDrive của chủ sở hữu | OneDrive policy |
| Chia sẻ trực tiếp từ SharePoint site | SharePoint site | SharePoint policy |

> **Lưu ý:** Rủi ro scope: Nếu chỉ cấu hình OneDrive, link tạo từ file nằm trong Teams channel/SharePoint sẽ không được bao phủ bởi policy OneDrive. Ngược lại, cấu hình SharePoint “Core” không bao gồm OneDrive.

## 2. Mô hình link chia sẻ của Microsoft

Microsoft hiện mô tả ba loại sharing link chính: Anyone, People in your organization và Specific people. Ngoài ra còn có “People with existing access” trong giao diện chia sẻ. Mỗi loại có ý nghĩa bảo mật khác nhau.

| Loại link | Đối tượng sử dụng | Ý nghĩa bảo mật / vận hành | Liên quan expiration |
| --- | --- | --- | --- |
| Anyone | Bất kỳ ai có link; có thể không cần đăng nhập | Rủi ro cao nhất; link có thể chuyển tiếp | Có policy riêng cho anonymous/Anyone; không phải trọng tâm tài liệu này |
| People in your organization | Bất kỳ người dùng nội bộ nào có link | Link có thể forward trong nội bộ; không dùng được cho guest/external | Có Max và Recommended expiration ở tenant và site level |
| Specific people | Chỉ các danh tính được chỉ định | Hẹp hơn về audience; quyền gắn với người được chọn | Không dùng các tham số OrganizationSharingLink*; cần quản trị riêng nếu muốn control loại link này |
| Existing access | Chỉ gửi đường dẫn cho người đã có quyền | Không cấp quyền mới | Không phải target của organization-link expiration policy |

> **Lưu ý:** Điểm cần hiểu: “Recommended expiration” là giá trị được hệ thống đề xuất/điền mặc định khi user tạo organization link. “Max expiration” là giới hạn cưỡng chế. Recommended phải <= Max.

## 3. Các policy/cmdlet chính của Microsoft

Tại thời điểm rà soát 25/09/2026, SharePoint Online Management Shell có các tham số riêng cho organization sharing link. Đây là thay đổi quan trọng so với nhiều bài Microsoft Q&A/tài liệu cũ trước 2026 vốn chỉ đề cập expiration cho Anyone links.

| Scope | Cmdlet / tham số | Tác dụng | Giá trị |
| --- | --- | --- | --- |
| Tenant - OneDrive | Set-SPOTenant -OneDriveOrganizationSharingLinkRecommendedExpirationInDays | Giá trị expiration đề xuất mặc định khi tạo organization link trên mọi OneDrive | 7-720 ngày; 0 = dùng Max |
| Tenant - OneDrive | Set-SPOTenant -OneDriveOrganizationSharingLinkMaxExpirationInDays | Tuổi tối đa của organization link trên mọi OneDrive | 7-720 ngày; 0 = bỏ yêu cầu expiration |
| Tenant - SharePoint | Set-SPOTenant -CoreOrganizationSharingLinkRecommendedExpirationInDays | Recommended expiration cho tất cả SharePoint sites, không gồm OneDrive | 7-720 ngày; 0 = dùng Max |
| Tenant - SharePoint | Set-SPOTenant -CoreOrganizationSharingLinkMaxExpirationInDays | Max expiration cho tất cả SharePoint sites, không gồm OneDrive | 7-720 ngày; 0 = bỏ yêu cầu expiration |
| Site | Set-SPOSite -OrganizationSharingLinkRecommendedExpirationInDays | Recommended expiration cho một site/OneDrive personal site | 7-720 ngày |
| Site | Set-SPOSite -OrganizationSharingLinkMaxExpirationInDays | Max expiration cho một site/OneDrive personal site | 7-720 ngày; 0 = bỏ yêu cầu |
| Site | Set-SPOSite -OverrideTenantOrganizationSharingLinkExpirationPolicy $true/$false | Cho phép site override tenant hoặc quay lại inherit tenant | Boolean |

> **Lưu ý:** Thứ tự policy: Site chỉ có hiệu lực khác tenant khi bật OverrideTenantOrganizationSharingLinkExpirationPolicy = $true. Khi đặt $false, site quay lại kế thừa tenant policy.

## 4. Phân biệt “default link type” và “default expiration”

Hai khái niệm này độc lập. Default link type quyết định user nhìn thấy loại link nào được chọn trước (Organization, SpecificPeople, Anyone). Expiration policy quyết định thời gian sống của organization link. Nếu mục tiêu là mọi thao tác chia sẻ ad-hoc nội bộ mặc định dùng organization link có expiration, cần kiểm tra cả hai.

| Thiết lập | Tenant | Site | Ý nghĩa |
| --- | --- | --- | --- |
| Default share link scope | Set-SPOTenant -OneDriveDefaultShareLinkScope / -CoreDefaultShareLinkScope | Set-SPOSite -DefaultShareLinkScope | Giá trị Organization, SpecificPeople, Anyone, Uninitialized |
| Default permission | Set-SPOTenant -OneDriveDefaultShareLinkRole / -CoreDefaultShareLinkRole | Set-SPOSite -DefaultShareLinkRole | View/Edit... tùy cmdlet |
| Recommended expiration | OneDriveOrganization... / CoreOrganization... | OrganizationSharingLinkRecommendedExpirationInDays | Ngày hết hạn đề xuất mặc định |
| Max expiration | OneDriveOrganization... / CoreOrganization... | OrganizationSharingLinkMaxExpirationInDays | Giới hạn cưỡng chế |

Nếu external sharing đã bị vô hiệu hóa ở tenant/site, việc đặt DefaultShareLinkScope = Organization không làm bật external sharing. Đây chỉ là lựa chọn mặc định trong phạm vi các loại link được policy cho phép.

## 5. Ma trận use case và policy phù hợp

| Use case | Cách phù hợp | Ưu điểm | Hạn chế |
| --- | --- | --- | --- |
| Toàn ngân hàng - OneDrive | Set-SPOTenant -OneDriveOrganization... | Native; đơn giản; không cần theo dõi membership | Áp cho mọi OneDrive |
| Toàn ngân hàng - cả OneDrive và SharePoint/Teams channel | Đặt cả OneDriveOrganization... và CoreOrganization... | Bao phủ chat và channel/sites | Cần đánh giá ảnh hưởng trên tất cả sites |
| Một cá nhân | Set-SPOSite trên personal site của user với OverrideTenant...=$true | Native, chính xác theo user | Phải xác định đúng OneDrive personal site |
| Một SharePoint site/Team | Set-SPOSite trên site tương ứng | Native, dễ kiểm soát | Không tự mở rộng sang site khác |
| Một nhóm users / một Khối | Không có native group scope cho OrganizationSharingLink expiration; dùng Entra group làm source + automation reconcile từng OneDrive site | Tự động theo membership; vận hành được ở quy mô lớn | Cần runbook, state, logging, rollback |
| Pilot một Khối rồi rollout toàn ngân hàng | Giai đoạn 1 group automation, giai đoạn 2 chuyển tenant-wide | Giảm rủi ro triển khai | Cần kế hoạch chuyển đổi và cleanup site override |

## 6. Cấu hình toàn tenant

### 6.1. Kiểm tra trạng thái hiện tại

```powershell
# Cài/ cập nhật module trước khi thực hiện trên máy quản trị
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser -Force

# Kết nối bằng tài khoản SharePoint Administrator, hỗ trợ MFA
Connect-SPOService -Url https://<tenant>-admin.sharepoint.com -UseSystemBrowser $true

# Chụp baseline tenant
Get-SPOTenant | Select-Object `
    OneDriveOrganizationSharingLinkRecommendedExpirationInDays, `
    OneDriveOrganizationSharingLinkMaxExpirationInDays, `
    CoreOrganizationSharingLinkRecommendedExpirationInDays, `
    CoreOrganizationSharingLinkMaxExpirationInDays, `
    OneDriveDefaultShareLinkScope, `
    CoreDefaultShareLinkScope | Format-List
```

### 6.2. Ví dụ: OneDrive toàn ngân hàng, mặc định 30 ngày, tối đa 180 ngày

```powershell
Set-SPOTenant `
  -OneDriveOrganizationSharingLinkRecommendedExpirationInDays 30 `
  -OneDriveOrganizationSharingLinkMaxExpirationInDays 180
```

### 6.3. Nếu muốn bao phủ cả SharePoint/Teams channel

```powershell
Set-SPOTenant `
  -OneDriveOrganizationSharingLinkRecommendedExpirationInDays 30 `
  -OneDriveOrganizationSharingLinkMaxExpirationInDays 180 `
  -CoreOrganizationSharingLinkRecommendedExpirationInDays 30 `
  -CoreOrganizationSharingLinkMaxExpirationInDays 180
```

> **Lưu ý:** Khuyến nghị: 30 ngày là giá trị mặc định hợp lý cho chia sẻ ad-hoc; 180 ngày là một guardrail để tránh link tồn tại quá lâu nhưng vẫn cho phép nghiệp vụ dài hạn. Giá trị cuối cùng phải được phê duyệt theo risk appetite và quy định lưu trữ nội bộ.

## 7. Cấu hình cho một cá nhân hoặc một site

OneDrive for Business của mỗi user là một SharePoint personal site riêng. Không nên tự suy diễn URL chỉ từ UPN vì URL có thể khác sau đổi UPN/tên miền hoặc do ký tự đặc biệt. Hãy lấy site thực tế từ SharePoint Online.

```powershell
# Liệt kê OneDrive personal sites và owner
$personalSites = Get-SPOSite -IncludePersonalSite $true -Limit All

$personalSites |
    Select-Object Url, Owner |
    Export-Csv .\OneDrive-PersonalSites.csv -NoTypeInformation -Encoding UTF8
```

Sau khi xác định site của user:

```powershell
$siteUrl = "https://<tenant>-my.sharepoint.com/personal/<actual-personal-site>"

Set-SPOSite `
  -Identity $siteUrl `
  -OverrideTenantOrganizationSharingLinkExpirationPolicy $true `
  -OrganizationSharingLinkRecommendedExpirationInDays 30 `
  -OrganizationSharingLinkMaxExpirationInDays 180
```

### 7.1. Rollback site về tenant policy

```powershell
Set-SPOSite `
  -Identity $siteUrl `
  -OverrideTenantOrganizationSharingLinkExpirationPolicy $false
```

> **Lưu ý:** Rollback: Khi override = false, site quay về policy tenant. Không cần tiếp tục duy trì Recommended/Max riêng cho site.

## 8. Cấu hình cho một nhóm users / một Khối

Microsoft chưa cung cấp tham số group scope cho OrganizationSharingLink expiration. Vì vậy giải pháp production phải tách “scope definition” và “enforcement”: Entra group xác định ai thuộc Khối; automation áp/rollback site-level override theo membership.

| Thành phần | Vai trò |
| --- | --- |
| Entra ID group | Nguồn sự thật về membership của Khối |
| Dynamic membership (khuyến nghị nếu HR attribute tin cậy) | Tự thêm/bớt user khi department/cost center/org code thay đổi |
| Azure Automation / scheduler | Chạy reconcile định kỳ |
| SharePoint Online Management Shell | Đọc và cập nhật OneDrive site policy |
| Microsoft Graph PowerShell | Đọc membership group |
| State store | Lưu site/user đã được automation quản lý để rollback an toàn khi user rời nhóm |
| Log/monitoring | Ghi Applied / Unchanged / Rollback / Missing site / Error |

### 8.1. Dynamic group

Nếu thuộc tính department được đồng bộ chuẩn từ HR/AD, ví dụ:

```powershell
user.department -eq "KHOI_CONG_NGHE"
```

Với mã đơn vị có nhiều giá trị có thể dùng -in. Dynamic group tự thêm/bớt user khi thuộc tính đổi. Tính năng dynamic membership yêu cầu Microsoft Entra ID P1 cho người dùng nằm trong dynamic group.

> **Lưu ý:** Không dùng memberOf preview cho production: Microsoft thông báo operator memberOf dynamic group đang kết thúc preview và sau 03/11/2026 sẽ ngừng cập nhật. Không nên thiết kế production phụ thuộc memberOf preview.

## 9. Script áp policy theo Entra group - bản vận hành có kiểm soát

Script dưới đây phù hợp để chạy thủ công hoặc làm lõi cho runbook. Nó có dry-run, không tự dựng URL OneDrive, dùng owner-to-site mapping, ghi log CSV và chỉ thay đổi site của member hiện tại. Phần rollback thành viên đã rời nhóm được xử lý ở mục 10 bằng state store để tránh đụng các site override do quản trị viên khác cấu hình.

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$GroupId,

    [int]$RecommendedDays = 30,
    [int]$MaxDays = 180,

    [switch]$Apply
)

$ErrorActionPreference = 'Stop'

if ($RecommendedDays -lt 7 -or $RecommendedDays -gt 720) {
    throw "RecommendedDays must be between 7 and 720."
}
if ($MaxDays -lt 7 -or $MaxDays -gt 720) {
    throw "MaxDays must be between 7 and 720."
}
if ($RecommendedDays -gt $MaxDays) {
    throw "RecommendedDays must be <= MaxDays."
}

$timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $PWD "OneDriveExpiry-$timeStamp.csv"
$results = [System.Collections.Generic.List[object]]::new()

# Interactive production admin run:
Connect-MgGraph -Scopes 'GroupMember.Read.All','User.Read.All' -NoWelcome
Connect-SPOService -Url 'https://<tenant>-admin.sharepoint.com' -UseSystemBrowser $true

# Get only user objects from the group's direct members.
$members = Get-MgGroupMemberAsUser -GroupId $GroupId -All `
    -Property 'id,displayName,userPrincipalName,accountEnabled'

# Build one lookup map instead of Where-Object across all sites for every user.
$sites = Get-SPOSite -IncludePersonalSite $true -Limit All
$siteByOwner = @{}
foreach ($s in $sites) {
    if (-not [string]::IsNullOrWhiteSpace($s.Owner)) {
        $siteByOwner[$s.Owner.ToLowerInvariant()] = $s
    }
}

foreach ($u in $members) {
    $upn = $u.UserPrincipalName
    if ([string]::IsNullOrWhiteSpace($upn)) { continue }

    $key = $upn.ToLowerInvariant()
    if (-not $siteByOwner.ContainsKey($key)) {
        $results.Add([pscustomobject]@{
            UPN=$upn; SiteUrl=''; Action='MissingOneDriveSite'; Status='Warning'; Error=''
        })
        continue
    }

    $site = $siteByOwner[$key]

    try {
        if ($Apply) {
            Set-SPOSite `
                -Identity $site.Url `
                -OverrideTenantOrganizationSharingLinkExpirationPolicy $true `
                -OrganizationSharingLinkRecommendedExpirationInDays $RecommendedDays `
                -OrganizationSharingLinkMaxExpirationInDays $MaxDays
            $action = 'Applied'
        }
        else {
            $action = 'WouldApply'
        }

        $results.Add([pscustomobject]@{
            UPN=$upn; SiteUrl=$site.Url; Action=$action; Status='Success'; Error=''
        })
    }
    catch {
        $results.Add([pscustomobject]@{
            UPN=$upn; SiteUrl=$site.Url; Action='Apply'; Status='Failed'; Error=$_.Exception.Message
        })
    }
}

$results | Export-Csv $logPath -NoTypeInformation -Encoding UTF8
$results | Group-Object Status,Action | Select-Object Count,Name | Format-Table -AutoSize
Write-Host "Log: $logPath"
```

> **Lưu ý:** Cách chạy an toàn: Lần đầu chạy không có -Apply để chỉ tạo danh sách WouldApply/MissingOneDriveSite. Kiểm tra CSV, đối chiếu membership và site URL, sau đó mới chạy lại với -Apply.

## 10. Reconciliation khi nhân sự vào/ra Khối

Đây là phần bắt buộc nếu triển khai cho một Khối có biến động nhân sự. Chỉ “apply member hiện tại” là chưa đủ: khi user rời Khối, site của họ vẫn còn override. Automation phải biết site nào do chính automation quản lý và rollback chúng.

Không nên rollback mọi site có OverrideTenantOrganizationSharingLinkExpirationPolicy = true vì có thể phá các exception hợp lệ do team khác quản trị. Cần state store riêng, ví dụ Azure Table Storage/Blob, SQL hoặc CMDB.

| State field tối thiểu | Mục đích |
| --- | --- |
| UserObjectId | Định danh bền vững của user |
| UPN | Thông tin vận hành/dễ đọc; không dùng làm khóa duy nhất vì UPN có thể đổi |
| OneDriveSiteUrl | Site đã được automation áp policy |
| PolicyId/Version | Phân biệt policy 30/180 với policy khác |
| FirstAppliedAt | Audit |
| LastSeenInGroupAt | Xác định membership |
| LastReconciledAt | Theo dõi job |
| Status | Managed / Removed / Error |

Thuật toán reconciliation:

| Tình huống | Hành động |
| --- | --- |
| User mới xuất hiện trong group, chưa có state | Resolve OneDrive site -> apply -> ghi Managed |
| User vẫn trong group, đã Managed | Verify; chỉ Set-SPOSite nếu config drift |
| User rời group nhưng state = Managed | Set OverrideTenant...=$false -> đánh dấu Removed |
| User chưa provision OneDrive | Không fail toàn job; ghi MissingOneDriveSite và thử lại kỳ sau |
| User đổi UPN | Dùng UserObjectId từ Graph để giữ identity; cập nhật UPN/site mapping |
| Set-SPOSite lỗi tạm thời | Retry có backoff; không cập nhật state thành success khi chưa thành công |

## 11. Tự động hóa Production bằng Azure Automation / Managed Identity

SharePoint Online Management Shell hiện hỗ trợ Connect-SPOService bằng system-assigned hoặc user-assigned managed identity; Microsoft Graph PowerShell cũng hỗ trợ Connect-MgGraph -Identity. Đây là phương án tốt hơn việc lưu username/password cho runbook.

```powershell
# SharePoint Online bằng system-assigned managed identity
Connect-SPOService `
  -Url https://<tenant>-admin.sharepoint.com `
  -ManagedIdentity

# Microsoft Graph bằng system-assigned managed identity
Connect-MgGraph -Identity -NoWelcome
```

Với user-assigned managed identity:

```powershell
Connect-SPOService `
  -Url https://<tenant>-admin.sharepoint.com `
  -ManagedIdentity `
  -ManagedIdentityType UserAssigned `
  -ManagedIdentityClientId <managed-identity-client-id>

Connect-MgGraph -Identity -ClientId <managed-identity-client-id> -NoWelcome
```

Managed identity phải được cấp quyền cần thiết trước khi chạy. Với Graph, GroupMember.Read.All cho phép ứng dụng đọc membership và basic group properties; chỉ cấp thêm User.Read.All khi script thực sự cần các thuộc tính user ngoài dữ liệu trả về từ endpoint group members. Với SharePoint, cấp quyền/role cho identity theo hướng dẫn Connect-SPOService và nguyên tắc least privilege của tenant; không dùng Global Administrator cho runbook thường trực.

> **Lưu ý:** Bảo mật production: Không hard-code secret/password trong script. Ưu tiên Managed Identity hoặc certificate-based app identity. Tách quyền deploy runbook, quyền chỉnh group, và quyền SharePoint admin để giảm rủi ro thay đổi trái phép.

## 12. Quy trình triển khai Production đề xuất

| Giai đoạn | Thao tác | Điều kiện pass |
| --- | --- | --- |
| 1. Baseline | Export tenant policy, default link scope, personal site list, group membership | Có bản lưu trước thay đổi |
| 2. Pilot | 5-10 user đại diện trong group riêng; Recommended=30, Max=180 | UI tạo org link có default expiration; user đổi được trong max |
| 3. Functional test | Test OneDrive web, Office desktop/web, Teams group chat; test expiry | Link mới có expiration; sau expiry link fail nhưng file vẫn tồn tại |
| 4. Negative test | User ngoài scope, Specific people link, existing-access link | Không bị tác động ngoài dự kiến |
| 5. Existing links | Kiểm tra link cũ > max age | Link Organization cũ được đánh giá theo ngày tạo và có thể bị coi hết hạn khi truy cập |
| 6. Automation dry-run | Run reconcile không Apply | Danh sách target chính xác |
| 7. Apply | Chạy với Apply; log đầy đủ | Không có Failed hoặc đã có incident record |
| 8. Membership lifecycle | Add/remove thử 1 user | Tự apply và rollback đúng |
| 9. Monitoring | Theo dõi job, drift, missing site | Có alert khi job fail hoặc error vượt ngưỡng |
| 10. Change management | Thông báo người dùng về default expiry và cách kéo dài | Helpdesk/runbook sẵn sàng |

## 13. Tác động tới link hiện hữu và dữ liệu

Theo tài liệu Microsoft hiện hành về People in your organization links: khi bật expiration policy, link mới được tạo sẽ nhận expiration. Link cũ không được sửa metadata để gắn ngày hết hạn ngay lập tức; tuy nhiên khi link cũ được truy cập sau khi policy có hiệu lực, hệ thống đánh giá tuổi link dựa trên ngày tạo ban đầu và giới hạn expiration hiện tại. Nếu tuổi link vượt giới hạn, link bị coi là hết hạn. Khi link hết hạn, file/folder không bị xóa; các quyền truy cập khác vẫn tiếp tục hoạt động.

> **Lưu ý:** Change impact: Việc đặt Max cho organization link có thể làm mất hiệu lực các link cũ có tuổi lớn hơn Max khi người dùng truy cập. Đây không chỉ là thay đổi UI “default date”; cần đánh giá tác động nghiệp vụ và truyền thông trước rollout tenant-wide.

## 14. Kiểm tra sau triển khai

### 14.1. Kiểm tra tenant

```powershell
Get-SPOTenant | Select-Object `
    OneDriveOrganizationSharingLinkRecommendedExpirationInDays, `
    OneDriveOrganizationSharingLinkMaxExpirationInDays, `
    CoreOrganizationSharingLinkRecommendedExpirationInDays, `
    CoreOrganizationSharingLinkMaxExpirationInDays | Format-List
```

### 14.2. Kiểm tra site

```powershell
Get-SPOSite -Identity $siteUrl -Detailed | Format-List *OrganizationSharingLink*
```

Nếu version module hiện tại không hiển thị property như mong muốn bằng wildcard, chạy Get-SPOSite -Identity $siteUrl -Detailed | Format-List * để đối chiếu đầy đủ output, đồng thời xác minh trực tiếp qua test tạo link trên UI.

### 14.3. Test case tối thiểu

| TC | Kịch bản | Kỳ vọng |
| --- | --- | --- |
| TC01 | User trong scope tạo People in organization link | Expiration mặc định = RecommendedDays |
| TC02 | User đổi expiration ngắn hơn | Được phép |
| TC03 | User đổi expiration dài hơn nhưng <= Max | Được phép |
| TC04 | User chọn ngày > Max | Bị giới hạn/không chấp nhận |
| TC05 | User ngoài scope | Kế thừa tenant policy |
| TC06 | User rời group | Sau reconcile site quay về inherit tenant |
| TC07 | Link hết hạn | Link không dùng được; file vẫn tồn tại |
| TC08 | File có quyền khác trực tiếp | Quyền khác vẫn hoạt động sau khi link hết hạn |
| TC09 | Teams group chat | File ở OneDrive; policy OneDrive áp dụng |
| TC10 | Teams channel | File ở SharePoint; chỉ được bao phủ nếu Core/site SharePoint policy được cấu hình |

## 15. Rollback và xử lý sự cố

### 15.1. Rollback tenant OneDrive về không yêu cầu expiration

```powershell
Set-SPOTenant `
  -OneDriveOrganizationSharingLinkMaxExpirationInDays 0
```

Theo cmdlet reference, Max=0 loại bỏ yêu cầu expiration. Khi dùng Recommended, cần kiểm tra lại trạng thái sau rollback và bảo đảm UI/tenant trở về behavior mong muốn.

### 15.2. Rollback site/group-managed site

```powershell
Set-SPOSite `
  -Identity $siteUrl `
  -OverrideTenantOrganizationSharingLinkExpirationPolicy $false
```

### 15.3. Các lỗi thường gặp

| Hiện tượng | Nguyên nhân khả dĩ | Xử lý |
| --- | --- | --- |
| Không tìm thấy OneDrive site | User chưa provision OneDrive hoặc owner mapping chưa sẵn sàng | Ghi warning; retry kỳ sau; không tự dựng URL |
| Set-SPOSite báo parameter không tồn tại | Module cũ | Update Microsoft.Online.SharePoint.PowerShell; xác nhận version trước change |
| Recommended > Max | Sai validation | Dừng script trước khi gọi cmdlet |
| User ngoài group vẫn có expiry | Tenant policy đang áp hoặc site có override khác | Kiểm tra tenant + site effective configuration |
| Teams channel không bị ảnh hưởng | File nằm ở SharePoint, không phải OneDrive | Cấu hình CoreOrganization... hoặc site policy phù hợp |
| Runbook mất quyền | Managed identity/app permission thay đổi | Alert; kiểm tra service principal/role/consent; không fallback sang stored password |

## 16. Mẫu policy vận hành doanh nghiệp đề xuất

| Control | Giá trị khởi điểm đề xuất | Lý do |
| --- | --- | --- |
| External sharing | Giữ Disabled theo posture hiện tại | Không liên quan use case nội bộ |
| Default share link scope cho pilot | Organization nếu mục tiêu là link rộng nội bộ | Đảm bảo Organization policy thực sự được sử dụng |
| Recommended organization-link expiration | 30 ngày | Phù hợp chia sẻ ad-hoc qua chat |
| Max organization-link expiration | 180 ngày | Cho phép user kéo dài nhưng tránh link vô thời hạn |
| Pilot scope | Một Khối qua Entra group | Giảm blast radius |
| Reconcile cadence | 1 lần/ngày; có thể tăng nếu HR change cần hiệu lực nhanh | Membership không cần realtime cho use case này |
| State store | Azure Table/Blob/CMDB | Rollback an toàn khi user rời group |
| Authentication | Managed Identity | Không lưu secret; phù hợp automation |
| Monitoring | Alert nếu job fail, có Failed result, hoặc MissingOneDriveSite kéo dài > N ngày | Phát hiện drift và provisioning issue |
| Rollout sau pilot | Cân nhắc tenant-wide OneDrive; thêm Core nếu muốn bao phủ Teams channels | Giảm phức tạp group automation lâu dài |

## 17. Governance và kiểm soát thay đổi

Đối với môi trường Production, policy expiration nên được quản lý như configuration baseline. Mọi thay đổi Recommended/Max hoặc scope phải có change ticket, before/after export, owner phê duyệt, test plan và rollback plan. Runbook nên có version control; tài khoản/identity automation không được quyền sửa Entra group nếu không cần thiết.

| Vai trò | Trách nhiệm |
| --- | --- |
| M365/SharePoint Admin | Thực thi tenant/site policy, quản lý module, kiểm tra hiệu lực |
| IAM/Entra Admin | Duy trì thuộc tính HR/dynamic group và quyền Graph |
| Security/GRC | Phê duyệt control objective, thời hạn, exception |
| Service Owner/Khối nghiệp vụ | Xác nhận use case, max duration và exception |
| SOC/Operations | Theo dõi automation failure/drift nếu tích hợp monitoring |

## 18. Tài liệu Microsoft tham chiếu

| ID | Tài liệu | URL |
| --- | --- | --- |
| MS-1 | Set-SPOTenant - Microsoft.Online.SharePoint.PowerShell | https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-spotenant?view=sharepoint-ps |
| MS-2 | Set-SPOSite - Microsoft.Online.SharePoint.PowerShell | https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/set-sposite?view=sharepoint-ps |
| MS-3 | Connect-SPOService | https://learn.microsoft.com/en-us/powershell/module/microsoft.online.sharepoint.powershell/connect-sposervice?view=sharepoint-ps |
| MS-4 | How shareable links work in OneDrive and SharePoint | https://learn.microsoft.com/en-us/sharepoint/shareable-links-anyone-specific-people-organization |
| MS-5 | Change the default sharing link for a site | https://learn.microsoft.com/en-us/sharepoint/change-default-sharing-link |
| MS-6 | Manage sharing settings for SharePoint and OneDrive | https://learn.microsoft.com/en-us/sharepoint/turn-external-sharing-on-or-off |
| MS-7 | Manage rules for dynamic membership groups in Microsoft Entra ID | https://learn.microsoft.com/en-us/entra/identity/users/groups-dynamic-membership |
| MS-8 | Create or update a dynamic membership group | https://learn.microsoft.com/en-us/entra/identity/users/groups-create-rule |
| MS-9 | Get-MgGroupMemberAsUser | https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.groups/get-mggroupmemberasuser?view=graph-powershell-1.0 |
| MS-10 | Connect-MgGraph | https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.authentication/connect-mggraph?view=graph-powershell-1.0 |
| MS-11 | Microsoft Graph permissions reference - GroupMember.Read.All | https://learn.microsoft.com/en-us/graph/permissions-reference |
| MS-12 | Azure Automation PowerShell runbook using Managed Identity | https://learn.microsoft.com/en-us/azure/automation/learn/powershell-runbook-managed-identity |
| MS-13 | Teams / SharePoint / OneDrive integration | https://learn.microsoft.com/en-us/microsoftteams/sharepoint-onedrive-interact |

Lưu ý: một số Microsoft Q&A trước năm 2026 nêu rằng organization links chưa có tenant/site expiration policy. Tài liệu này ưu tiên cmdlet reference hiện hành của Microsoft Online SharePoint PowerShell tại ngày 25/09/2026, nơi các tham số OrganizationSharingLink* đã được công bố chính thức.


---

## Phụ lục: vận hành bằng repo này

### Quy trình thay đổi PROD

1. Chạy `Get-PolicyBaseline.ps1`.
2. Export danh sách member group và OneDrive site để review.
3. Chạy `Invoke-GroupReconcile.ps1` không có `-Apply`.
4. Review các trạng thái:
   - `Unchanged`
   - `WouldChange`
   - `MissingPersonalSite`
   - `Error`
5. Chỉ khi scope đúng mới chạy lại với `-Apply`.
6. Kiểm tra CSV log và state file.
7. Test UI bằng account pilot.
8. Lặp lại reconcile theo lịch.

### Nguyên tắc rollback

Không rollback bằng cách quét mọi OneDrive site có `Override=true`, vì có thể có site được override thủ công vì mục đích khác.

Repo chỉ rollback các site được ghi nhận trong state của chính automation.

### Xử lý MissingPersonalSite

Trạng thái này thường có nghĩa user chưa từng provision OneDrive hoặc site không còn tồn tại. Không tự tạo OneDrive chỉ để áp policy. Ghi nhận, theo dõi, và lần reconcile sau sẽ áp khi site xuất hiện.

### Khi user rời Khối

Ở lần reconcile sau:

- user không còn trong group;
- site URL vẫn nằm trong managed state;
- script đặt `OverrideTenantOrganizationSharingLinkExpirationPolicy = false`;
- site quay về tenant policy;
- site bị xóa khỏi managed state sau khi verify thành công.
