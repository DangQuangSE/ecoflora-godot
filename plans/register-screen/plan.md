# Plan: RegisterScreen — Godot đăng ký tài khoản
Status: Complete
Date: 2026-06-06
Mode: Fast

## Overview
Thêm màn hình đăng ký (`RegisterScene`) trong Godot client, mirror UI/UX của `LoginScene`, gọi `POST /api/auth/register` trên backend .NET đã có sẵn. Sau đăng ký thành công, **quay về LoginScene** và hiển thị thông báo thành công — **không** auto-login, **không** lưu tokens.

**Backend:** Không cần thay đổi — `AuthController.Register`, `RegisterRequest`, `RegisterValidator`, `UserService.Register` đã hoàn chỉnh.

## User Decisions (2026-06-06)
| # | Quyết định |
|---|------------|
| 1 | Sau đăng ký → `LoginScene` + thông báo thành công |
| 2 | Một field duy nhất "Tài khoản hoặc Email" — client tự map sang `email` hoặc `username` |
| 3 | Form bọc trong `ScrollContainer` (form dài trên mobile) |

## Phases
- [x] Phase 1: Service Layer — `AuthService` + `UserManager.register_async`
- [x] Phase 2: Register Scene — `RegisterScene.tscn` + `RegisterScene.gd`
- [x] Phase 3: Navigation — liên kết Login ↔ Register, cập nhật `SceneTransition`

## API Contract (reference)

### Request — `POST /api/auth/register`
```json
{
  "firstName": "Nguyen",
  "lastName": "Van A",
  "email": "user@example.com",
  "username": "player01",
  "password": "secret123"
}
```

### Success — `200`
```json
{
  "isSuccess": true,
  "message": "Đăng ký thành công.",
  "data": {
    "accessToken": "...",
    "refreshToken": "..."
  }
}
```

### Error — `400`
```json
{
  "status": false,
  "code": 400,
  "message": "Email đã tồn tại."
}
```

### Account field mapping (client → BE)
User nhập một field `account`. Client detect:
- Có `@` → gửi `{ email: account, username: "" }`
- Không có `@` → gửi `{ email: "", username: account }`

### Validation rules (BE — mirror on client)
| Field | Rule |
|-------|------|
| firstName | Required, max 50 |
| lastName | Required, max 50 |
| account | Required — email format nếu có `@`, else username ≥ 3 |
| password | Required, min 6 |
| confirmPassword | Client-only — phải khớp password |

## Dependencies
- BE register endpoint live tại `UserManager.base_url` (hiện `http://20.40.58.246:5000`)
- `LoginScene` assets: `login_bg.png`, `login_frame.png`, `login_button.png`, `logo.png`
- `SceneTransition` autoload đã có `fade_to()`

## Risks
- LOW: BE trả tokens trong response nhưng client **bỏ qua** — user phải login thủ công sau đăng ký (theo design)
- LOW: `_http` đang dùng cho login — register cần HTTPRequest riêng để tránh conflict `_request_in_flight`
- LOW: `use_mock` path — `register_async` emit `register_succeeded` ngay, không HTTP
- NOTED: Confirm password chỉ validate client-side, không gửi lên BE
- NOTED: `ScrollContainer` cần `custom_minimum_size` hoặc size flags để scroll hoạt động trong frame cố định

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-06
**Phase in progress:** (complete)
**Status:** All 3 phases implemented — RegisterScreen ready for manual test in Godot Editor

### Decisions made this session
- `parse_register_success` delegates envelope check only — tokens from BE intentionally discarded
- Single `AccountField` mapped via `AuthService.resolve_account_fields()`
- `SuccessLabel` + `RegisterLink` added to LoginScene; `LoginLink` on RegisterScene
- Separate `_http_register` HTTPRequest node in UserManager

### Next immediate action
Manual test: Login → Đăng ký → fill form → verify success message on LoginScene → login with new account

## Cook Command
```
/ck:cook --fast plans/register-screen/plan.md
```
