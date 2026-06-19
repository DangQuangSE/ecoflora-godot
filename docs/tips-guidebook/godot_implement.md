# Hướng dẫn Godot — Mẹo Chơi (Tips Guidebook)

Tài liệu hướng dẫn kiểm tra tính năng **Mẹo Chơi** sau khi code đã được implement.

---

## 1. Mở Scene và kiểm tra cấu trúc Node

1. Mở Godot 4 → **FileSystem** → double-click `res://scenes/hud/HUD.tscn`
2. Scene tree liên quan:

```
HUD (CanvasLayer)
├── InventoryPanel (instance)
├── TipsPanel (instance)          ← MỚI — panel mẹo chơi
├── HarvestButton
├── ShopButton
├── VitalityBar (instance)        ← có thêm TipsButton
└── ShopScene (instance)
```

3. Mở `res://scenes/hud/VitalityBar.tscn`:

```
VitalityBar (Control)
└── VBoxContainer
    ├── HeartIcon (TextureRect)     ← res://assets/icon/heart.png
    ├── TipsButton (Button)         ← MỚI — icon sách
    │   └── Icon (TextureRect)      ← res://assets/icon/tip_icon.png
    └── CountdownLabel (Label)
```

4. Mở `res://scenes/tips/TipsPanel.tscn`:

```
TipsPanel (Control)
├── BGDimmer (ColorRect)
└── PanelRoot (Panel)
    └── VBox
        ├── TitleBar → TitleLabel "Mẹo Chơi" + CloseBtn
        ├── Divider
        ├── Tabs (HBoxContainer)    ← mỗi tip.title = một tab
        └── Scroll → TipsList       ← title + một đoạn content
```

---

## 2. Gán Script và Resource

| File | Ghi chú |
|------|---------|
| `domain/GameTip.gd` | Model mỗi tip — `title` + `content` |
| `domain/TipCatalog.gd` | Offline fallback khi BE lỗi |
| `services/TipService.gd` | Parse `GET /api/gametips` |
| `autoloads/TipManager.gd` | Fetch + cache tips |
| `scenes/tips/TipsPanel.gd` | Đọc từ `TipManager` |
| `scenes/hud/VitalityBar.gd` | Signal `tips_pressed` |
| `scenes/hud/HUD.gd` | Wire `_toggle_tips()` |

**Nội dung tips** lấy từ backend — admin sửa qua Swagger (`docs/tips-from-db/admin-api.md` trên eco-backend).

---

## 3. Cài đặt Inspector

### VitalityBar.tscn

| Node | Property | Giá trị |
|------|----------|---------|
| VitalityBar | Custom Minimum Size | `52 × 124` |
| TipsButton | Custom Minimum Size | `48 × 48` |
| TipsButton/Icon | Texture | `res://assets/icon/tip_icon.png` (code cũng load) |

### HUD.tscn

| Node | Property | Ghi chú |
|------|----------|---------|
| VitalityBar | offset_bottom | `282` (cao hơn trước để chứa nút sách) |
| TipsPanel | Vị trí trong tree | **Sau InventoryPanel, trước VitalityBar** |

---

## 4. Wiring Signals

Đã wire qua code — **không cần kết nối thủ công**:

| Signal | Nguồn | Nhận |
|--------|-------|------|
| `tips_pressed` | `VitalityBar` | `HUD._toggle_tips()` |
| `pressed` | `TipsPanel.CloseBtn` | `hide_panel()` |
| `gui_input` | `TipsPanel.BGDimmer` | `hide_panel()` |

---

## 5. Smoke Test Checklist

- [ ] Chạy game → icon sách hiển thị **dưới tim**, trên countdown
- [ ] Bấm icon sách → panel **"Mẹo Chơi"** mở, tab **"Hệ Sinh Thái"** active
- [ ] Nội dung tab là **một đoạn văn** (không còn nhiều tiểu mục)
- [ ] Bấm ✕ hoặc chạm vùng tối → panel đóng
- [ ] Bấm lại icon sách khi panel mở → panel đóng (toggle)
- [ ] Mở kho đồ → mở mẹo chơi → kho đồ tự đóng
- [ ] Mở cửa hàng → mở mẹo chơi → shop tự đóng
- [ ] Bấm tim khi vitality sẵn sàng → vẫn claim được; bấm icon sách không claim

### Test tự động

```bash
godot --headless --script res://tools/test_tip_catalog.gd
godot --headless --script res://tools/test_tip_service.gd
```

---

## 6. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|-------------|-------------|----------|
| Không thấy icon sách | Thiếu `tip_icon.png` hoặc TipsButton chưa thêm | Kiểm tra `VitalityBar.tscn` |
| Bấm sách không mở panel | TipsPanel chưa instance trong HUD | Kiểm tra `HUD.tscn` có node TipsPanel |
| Bấm sách không đóng được | TipsPanel đặt sau VitalityBar trong tree | Di chuyển TipsPanel lên trước VitalityBar |
| Tab trống | TipCatalog lỗi | Chạy `test_tip_catalog.gd` |
| Bấm sách lại claim tim | TipsButton không phải Button riêng | Đảm bảo TipsButton là child VBox, không dùng chung _gui_input |

---

## 7. Thêm tip mới (admin)

1. Swagger → `POST /api/gametips` (xem `eco-backend/docs/tips-from-db/admin-api.md`)
2. Body: `title`, `content`, `sortOrder`
3. Restart game hoặc đăng nhập lại → tab mới xuất hiện
