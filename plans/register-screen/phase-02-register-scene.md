# Phase 2: Register Scene UI

## Layer
`scenes/auth/`

## Files

| File | Layer | New / Modify |
|------|-------|--------------|
| `scenes/auth/RegisterScene.tscn` | scenes | New |
| `scenes/auth/RegisterScene.gd` | scenes | New |

## Requirements
Màn hình đăng ký mirror `LoginScene`: cùng background, frame, button style, loading overlay, error label. Form trong `ScrollContainer`. Một field account (username hoặc email). Sau success → quay LoginScene.

## Steps

1. **Duplicate scene structure từ LoginScene.tscn**
   - Copy: `Background`, `Logo`, `RegisterFrame`, `FormArea` (MarginContainer)
   - Reuse textures: `login_bg.png`, `login_frame.png`, `login_button.png`, `logo.png`
   - Giữ frame size giống Login (`offset_top = -195`, `offset_bottom = 195`)

2. **ScrollContainer** (bọc form)
   Node tree:
   ```
   RegisterFrame
   └── FormArea (MarginContainer — margins giống Login)
       └── ScrollContainer
           └── FormContent (VBoxContainer)
   ```
   - `ScrollContainer`: `horizontal_scroll_mode = DISABLED`, `vertical_scroll_mode = AUTO`
   - `size_flags_vertical = SIZE_EXPAND_FILL`
   - `custom_minimum_size.y` đủ để scroll khi nội dung vượt frame

3. **Form fields** (trong `FormContent`, mỗi field = Wrapper + LineEdit)
   | Node | Placeholder | Notes |
   |------|-------------|-------|
   | FirstNameField | Họ | |
   | LastNameField | Tên | |
   | AccountField | Tài khoản hoặc Email | Giống LoginScene username field |
   | PasswordField | Mật khẩu | `secret = true` |
   | ConfirmPasswordField | Xác nhận mật khẩu | `secret = true`, client-only |

4. **Button + labels** (cuối FormContent, ngoài scroll nếu cần — hoặc trong scroll)
   - `RegisterBtn` text = "Đăng ký"
   - `ErrorLabel` — ẩn mặc định, autowrap
   - `LoadingOverlay` + `LoadingLabel` text = "Đang đăng ký..."

5. **RegisterScene.gd — script**
   - `@onready` refs cho tất cả fields + ScrollContainer
   - `_ready()`: `SceneTransition.force_clear()`, `WeatherManager.set_overlay_visible(false)`, `_apply_theme()`, connect signals
   - Nếu `UserManager.is_logged_in()` → `SceneTransition.fade_to(GARDEN_SCENE)` (edge case)
   - Connect `UserManager.register_succeeded` → `on_register_success`
   - Connect `UserManager.register_failed` → `show_error`
   - `_apply_theme()` — StyleBoxFlat cho tất cả LineEdit (copy từ LoginScene)

6. **Client validation** (`_validate_form() -> String`)
   - Họ, Tên không rỗng
   - Account không rỗng
   - Account có `@` → kiểm tra email đơn giản (`@` + `.`)
   - Account không có `@` → length ≥ 3
   - Mật khẩu ≥ 6 ký tự
   - Confirm password khớp password

7. **`_on_register_pressed()`**
   - Validate → show error nếu fail
   - `_set_loading(true)`, clear error
   - `UserManager.register_async(first, last, account, password)`

8. **Enter key** — `gui_input` trên `ConfirmPasswordField` → submit

9. **`on_register_success()`**
   - `_set_loading(false)`
   - `SceneTransition.fade_to("res://scenes/auth/LoginScene.tscn")`
   - Message đã nằm trong `UserManager._registration_success_message` — LoginScene sẽ đọc

## Success Criteria
- RegisterScene có ScrollContainer, scroll được khi form dài
- Chỉ một field account (không có Email + Username riêng)
- Submit rỗng → lỗi client-side
- Submit hợp lệ + BE → fade về LoginScene
- Submit trùng account → ErrorLabel hiện message BE
- Enter trên confirm field trigger submit

## Spec Coverage
- P1: UI đăng ký với ScrollContainer + single account field
- P2: Validation client + hiển thị lỗi BE
