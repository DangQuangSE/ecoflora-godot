# Phase 2: Scenes — TipsPanel

testing: default

## Layer

`scenes/` — imports `domain/`; autoload `AudioManager` permitted for SFX

## Files

| File | Layer | Action |
|---|---|---|
| `scenes/tips/TipsPanel.gd` | scenes | CREATE |
| `scenes/tips/TipsPanel.tscn` | scenes | CREATE |

---

## Requirements

Panel modal giống kho đồ: dimmer, tiêu đề cố định **"Mẹo Chơi"**, **tab theo chủ đề** (mirror style tab `InventoryPanel`), vùng scroll hiển thị danh sách tip (title + body) của tab đang chọn. Đóng bằng ✕, chạm dimmer, hoặc HUD toggle (Phase 3).

---

## Steps

1. Tạo `TipsPanel.tscn` (`Control`, full rect): `BGDimmer`, `PanelRoot`/VBox, `TitleBar` (Label **"Mẹo Chơi"** + CloseBtn), `Tabs` HBoxContainer (nút tab tạo động hoặc hardcode v1), `ScrollContainer` → `TipsList` VBoxContainer.

2. **Không** dùng Prev/Next. Mỗi tip trong tab = một block UI (vd. `TitleLabel` bold + `BodyLabel` autowrap + `HSeparator`), add vào `TipsList` khi đổi tab.

3. Viết `TipsPanel.gd` (`class_name TipsPanelNode`):
   - Load categories từ `TipCatalog.get_categories()`
   - `_current_category_id: String`
   - `_set_category(id)` → rebuild `TipsList` từ `get_tips_for_category()`
   - Tab style mirror `InventoryPanel._build_tab_styles()` / `_update_tab_styles()`
   - `show_panel()` / `hide_panel()`, SFX click giống inventory

4. Wire CloseBtn + dimmer tap → `hide_panel()`.

5. `visible = false` trong `_ready()`. v1 một tab "Hệ Sinh Thái" — tab bar vẫn hiển thị (active mặc định).

6. Style: palette nâu/vàng inventory hoặc tông sách (`tip_icon.png`); `PrimaryButton` cho CloseBtn nếu project dùng.

---

## Success Criteria

- `show_panel()` → tab "Hệ Sinh Thái" active, hiển thị ≥4 tip synergy
- Scroll được khi nội dung dài
- CloseBtn và dimmer ẩn panel
- `godot --headless --check-only --script res://scenes/tips/TipsPanel.gd` pass

---

## Risks

- Tab bar 1 tab trông hơi trống — chấp nhận v1; thêm chủ đề sau không đổi layout
- Reuse `inventory_bg.png` region hoặc StyleBoxFlat nếu chưa có frame riêng
