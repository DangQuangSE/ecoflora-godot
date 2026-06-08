# Phase 1: Service Layer — Register API

## Layer
`services/` + `autoloads/UserManager.gd`

## Files

| File | Layer | New / Modify |
|------|-------|--------------|
| `services/AuthService.gd` | services | Modify |
| `autoloads/UserManager.gd` | autoloads | Modify |

## Requirements
Gọi `POST /api/auth/register`, kiểm tra `isSuccess`, **không lưu tokens**, lưu thông báo thành công để LoginScene hiển thị, emit signals cho UI.

## Steps

1. **AuthService — `resolve_account_fields`**
   Helper map một field `account` sang email/username:
   ```gdscript
   func resolve_account_fields(account: String) -> Dictionary:
       var trimmed := account.strip_edges()
       if "@" in trimmed:
           return {"email": trimmed, "username": ""}
       return {"email": "", "username": trimmed}
   ```

2. **AuthService — `build_register_body`**
   ```gdscript
   func build_register_body(first_name: String, last_name: String,
       account: String, password: String) -> String:
       var fields := resolve_account_fields(account)
       return JSON.stringify({
           "firstName": first_name,
           "lastName": last_name,
           "email": fields["email"],
           "username": fields["username"],
           "password": password,
       })
   ```
   Key names camelCase khớp `RegisterRequest` C#.

3. **AuthService — `parse_register_success`**
   Chỉ kiểm tra envelope, **không** extract tokens:
   ```gdscript
   func parse_register_success(json: Dictionary) -> String:
       if not json.get("isSuccess", false):
           return ""
       return str(json.get("message", "Đăng ký thành công."))
   ```

4. **UserManager — signals + message buffer**
   ```gdscript
   signal register_succeeded
   signal register_failed(reason: String)

   var _registration_success_message: String = ""

   func take_registration_success_message() -> String:
       var msg := _registration_success_message
       _registration_success_message = ""
       return msg
   ```

5. **UserManager — HTTPRequest riêng**
   Trong `_ready()`:
   ```gdscript
   var _http_register: HTTPRequest
   var _register_in_flight: bool = false
   ```
   Tạo child `_http_register` (timeout 10s) — tách khỏi `_http` login.

6. **UserManager — `register_async`**
   Signature:
   ```gdscript
   func register_async(first_name: String, last_name: String,
       account: String, password: String) -> bool
   ```
   Flow:
   - `use_mock` → set `_registration_success_message = "Đăng ký thành công."` → `register_succeeded.emit()` → return true
   - Guard `_register_in_flight`
   - POST `base_url + "/api/auth/register"`
   - Network error → `register_failed("Lỗi kết nối...")`
   - 400 → parse `message` → `register_failed(msg)`
   - != 200 → `register_failed("Lỗi máy chủ (%d)...")`
   - 200 → `parse_register_success(data)` → nếu rỗng → `register_failed("Đăng ký thất bại.")`
   - Success → `_registration_success_message = msg` → `register_succeeded.emit()` — **không** gọi `_token_store`, **không** `fetch_profile_async()`

7. **UserManager — cleanup**
   Trong `_exit_tree()`: cancel `_http_register` nếu `_register_in_flight`.

## Success Criteria
- `register_async(...)` với BE chạy trả `true`, `TokenStore` **không** có accessToken mới
- `take_registration_success_message()` trả message BE sau success, rỗng sau lần gọi thứ hai
- 400 duplicate email → `register_failed` với message tiếng Việt
- `use_mock = true` → `register_succeeded` emit, message buffer set
- Login flow không regression

## Spec Coverage
- P1: Gọi register API, không auto-login
