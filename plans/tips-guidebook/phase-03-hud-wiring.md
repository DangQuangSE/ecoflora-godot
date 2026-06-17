# Phase 3: Scenes — VitalityBar & HUD Wiring

testing: default

## Layer

`scenes/` — imports autoloads + domain (gián tiếp qua TipsPanel)

## Files

| File | Layer | Action |
|---|---|---|
| `scenes/hud/VitalityBar.tscn` | scenes | MODIFY |
| `scenes/hud/VitalityBar.gd` | scenes | MODIFY |
| `scenes/hud/HUD.tscn` | scenes | MODIFY |
| `scenes/hud/HUD.gd` | scenes | MODIFY |

---

## Requirements

Đặt nút `tip_icon.png` ngay dưới `HeartIcon` trong VitalityBar. Bấm nút mở `TipsPanel` từ HUD. Đóng inventory/shop nếu đang mở. Heart vẫn claim vitality bình thường.

---

## Steps

1. Sửa `VitalityBar.tscn`: trong `VBoxContainer`, thứ tự `HeartIcon` → `CountdownLabel` → `TipsButton` (**Button** 72×72, `flat = true`, child `Icon` TextureRect `tip_icon_v2.png`). Tăng `custom_minimum_size` (~72×148). Heart claim vẫn qua `_gui_input` trên parent Control — `TipsButton` phải là Button riêng để không lẫn với claim.

2. Sửa `VitalityBar.gd`: thêm `signal tips_pressed`, wire `TipsButton.pressed` → emit signal. Load texture `res://assets/icon/tip_icon.png` trong `_ready()`. **Không** gắn logic mở panel vào VitalityBar — chỉ signal.

3. Instance `TipsPanel.tscn` trong `HUD.tscn` — **đặt ngay sau `InventoryPanel`, trước `VitalityBar`** (cùng thứ tự draw như inventory: dimmer phủ HUD nhưng VitalityBar vẫn trên dimmer để nút tips toggle-close hoạt động). Full screen anchors.

4. Sửa `HUD.gd`: `@onready var _tips_panel`, connect `VitalityBar.tips_pressed` → `_toggle_tips()`. **Toggle:** nếu tips visible → `hide_panel()`; else đóng inventory/shop → `show_panel()`. Bấm lại icon sách khi panel mở phải đóng (giống `_toggle_inventory()`).

5. Mutual exclusivity **hai chiều** cho cả 3 panel:
   - `_toggle_inventory()` → đóng tips nếu visible
   - `_toggle_tips()` → đóng inventory (`hide_panel()`) và shop (`_shop_panel.hide()`) nếu đang mở
   - `_open_shop()` / `open_shop()` → đóng tips trước khi `show_panel()`

6. Kiểm tra layout HUD tại vị trí VitalityBar (offset_top ~158, trái màn hình) — không chồng UserHUD hoặc joystick.

---

## Success Criteria

- Trong game, countdown hiển thị dưới tim; icon sách ở dưới cùng
- Tap icon sách → TipsPanel mở; **tap lại icon sách**, ✕, hoặc chạm dimmer → đóng
- Tap tim khi vitality ready → claim vẫn hoạt động; tap icon sách không trigger claim
- Mở kho đồ / shop rồi mở tips → panel kia đóng trước (và ngược lại)
- Portrait 720×1280: VitalityBar không chồng UserHUD hoặc joystick
- Smoke: chạy main scene, thao tác tips + inventory không lỗi console

---

## Risks

- VitalityBar cao hơn: điều chỉnh `offset_bottom` trong HUD.tscn nếu cần
- `TipsButton` cần `mouse_filter` đúng để không block heart — heart và tips là sibling buttons, tách biệt
