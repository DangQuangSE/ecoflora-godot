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
        ├── Tabs (HBoxContainer)    ← tab tạo động từ TipCatalog
        └── Scroll → TipsList (VBoxContainer)
```

---

## 2. Gán Script và Resource

| File | Ghi chú |
|------|---------|
| `domain/GameTip.gd` | Model mỗi mẹo — **đã gán class_name** |
| `domain/TipCatalog.gd` | Danh sách tips theo chủ đề — **không cần Inspector** |
| `scenes/tips/TipsPanel.gd` | Đã gán trên TipsPanel root |
| `scenes/hud/VitalityBar.gd` | Đã gán — có signal `tips_pressed` |
| `scenes/hud/HUD.gd` | Đã wire `_toggle_tips()` |

**Không cần** tạo Resource `.tres` mới — nội dung tips nằm trong `TipCatalog.gd`.

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
- [ ] Cuộn xem ≥5 mẹo về synergy zone
- [ ] Bấm ✕ hoặc chạm vùng tối → panel đóng
- [ ] Bấm lại icon sách khi panel mở → panel đóng (toggle)
- [ ] Mở kho đồ → mở mẹo chơi → kho đồ tự đóng
- [ ] Mở cửa hàng → mở mẹo chơi → shop tự đóng
- [ ] Bấm tim khi vitality sẵn sàng → vẫn claim được; bấm icon sách không claim

### Test tự động (domain)

```bash
godot --headless --script res://tools/test_tip_catalog.gd
```

Kết quả mong đợi: `TipCatalog tests: all passed`

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

## 7. Thêm chủ đề / mẹo mới sau này

1. Mở `domain/TipCatalog.gd`
2. Thêm entry vào `get_categories()` (vd. `{"id": "harvest", "label": "Thu Hoạch"}`)
3. Thêm case trong `get_tips_for_category()` hoặc hàm riêng
4. Thêm `GameTip.new(...)` với `id`, `category_id`, `title`, `body`
5. Chạy lại game — tab mới xuất hiện tự động
