# Security

Repo chứa script có khả năng thay đổi cấu hình Microsoft 365 production.

## Quy tắc

- Không commit credential, certificate private key, access token, tenant secret.
- Không commit `config/policy.json` nếu trong đó có thông tin nội bộ không muốn công khai.
- Không commit state/log production.
- Không tự động chạy script apply bằng GitHub Actions.
- GitHub Actions trong repo chỉ dùng lint/static analysis.
- Mọi thay đổi production phải qua dry-run + review.

## Files bị ignore

`.gitignore` loại trừ:

- `config/policy.json`
- `state/`
- `logs/`
- `output/`
- local PowerShell artifacts
