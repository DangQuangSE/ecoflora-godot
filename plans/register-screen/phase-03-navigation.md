# Phase 3: Navigation — Login ↔ Register + Success Message

## Layer
`scenes/auth/` + `autoloads/SceneTransition.gd`

## Files

| File | Layer | New / Modify |
|------|-------|--------------|
| `scenes/auth/LoginScene.tscn` | scenes | Modify |
| `scenes/auth/LoginScene.gd` | scenes | Modify |
| `scenes/auth/RegisterScene.tscn` | scenes | Modify |
| `scenes/auth/RegisterScene.gd` | scenes | Modify |
| `autoloads/SceneTransition.gd` | autoloads | Modify |

## Requirements
Navigation hai chiều Login ↔ Register. Sau đăng ký thành công, LoginScene hiển thị thông báo xanh từ `UserManager.take_registration_success_message()`.

## Steps

1. **SceneTransition allowlist**
   Thêm vào `ALLOWED_SCENES`:
   ```gdscript
   "res://scenes/auth/RegisterScene.tscn",
   ```

2. **LoginScene — SuccessLabel**
   Thêm `SuccessLabel` (Label) trong `FormContent`, trên `ErrorLabel`:
   - Ẩn mặc định (`visible = false`)
   - `autowrap_mode = 3`, `horizontal_alignment = 1`
   - Theme: font size 13, `font_color = Color(0.1, 0.55, 0.2)` (xanh)

3. **LoginScene.gd — hiển thị message sau register**
   Trong `_ready()`, sau setup hiện tại:
   ```gdscript
   var success_msg := UserManager.take_registration_success_message()
   if not success_msg.is_empty():
       _show_success(success_msg)
   ```
   Thêm helpers:
   ```gdscript
   func _show_success(msg: String) -> void:
       _error_label.visible = false
       _success_label.text = msg
       _success_label.visible = true

   func _show_error(msg: String) -> void:
       _success_label.visible = false
       # existing error logic...
   ```
   Khi user bắt đầu login (`_on_login_pressed`) → ẩn `_success_label`.

4. **LoginScene — link đăng ký**
   Thêm `Button` flat/text dưới labels trong `FormContent`:
   - Text: "Chưa có tài khoản? Đăng ký"
   - Font size 13, màu link `Color(0.2, 0.45, 0.75)`
   - `pressed` → `SceneTransition.fade_to("res://scenes/auth/RegisterScene.tscn")`

5. **RegisterScene — link đăng nhập**
   Thêm link trong `FormContent` (cuối form, trong ScrollContainer):
   - Text: "Đã có tài khoản? Đăng nhập"
   - `pressed` → `SceneTransition.fade_to("res://scenes/auth/LoginScene.tscn")`

6. **Không đổi main_scene**
   `project.godot` vẫn `LoginScene.tscn`.

## Success Criteria
- Login → Register → đăng ký thành công → fade Login → **SuccessLabel** hiện "Đăng ký thành công." (hoặc message BE)
- Click "Đăng nhập" trên Register → về Login không có success message
- Boot game vẫn mở LoginScene
- Bắt đầu login → success label ẩn, error label hoạt động bình thường

## Spec Coverage
- P1: Navigation hai chiều + thông báo thành công trên LoginScene
