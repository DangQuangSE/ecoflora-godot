# Hướng dẫn thiết lập Godot Editor — Currency, Vitality Bar & Shop

## 1. Mở Scene và kiểm tra cấu trúc Node

### UserHUD.tscn — thêm CoinLabel
1. Mở `res://scenes/hud/UserHUD.tscn`
2. Trong Scene tree, chọn node gốc `UserHUD (Control)`
3. Thêm node con: **Add Child Node → Label**, đặt tên `CoinLabel`
4. Trong Inspector của `CoinLabel`:
   - `Text`: `0`
   - Căn chỉnh vị trí: đặt bên cạnh XPBar hoặc phía dưới LevelLabel tùy layout
5. Script `UserHUD.gd` đã sẵn sàng — biến `_coin_label` sẽ tự link khi chạy

### HUD.tscn — thêm ShopButton và VitalityBar
1. Mở `res://scenes/hud/HUD.tscn`
2. Thêm node con: **Add Child Node → Button**, đặt tên `ShopButton`
   - Inspector: `Text` = `🏪` hoặc gán icon texture tùy ý
   - Đặt vị trí góc trên bên phải màn hình
3. Thêm instance VitalityBar:
   - Kéo `res://scenes/hud/VitalityBar.tscn` vào Scene tree của HUD
   - Đặt tên instance là `VitalityBar`
   - Điều chỉnh vị trí theo layout (góc trên hoặc phía dưới UserHUD)
4. Script `HUD.gd` đã có `_shop_btn` và `_open_shop()` — chạy được ngay

---

## 2. Tạo VitalityBar.tscn (scene mới hoàn toàn)

1. **File → New Scene**, chọn root node là `Control`, đặt tên `VitalityBar`
2. Cấu trúc node bên trong:

```
VitalityBar (Control)
├── HBoxContainer
│   ├── HeartIcon (TextureRect)        ← gán ảnh tim (hoặc emoji label)
│   ├── FillBar (ProgressBar)          ← min=0, max=21600, step=1
│   ├── CountdownLabel (Label)         ← text="--:--:--"
│   └── ClaimButton (Button)           ← text="Nhận thưởng"
```

3. Gán script: chọn node `VitalityBar` → **Attach Script** → chọn `res://scenes/hud/VitalityBar.gd`
4. **Lưu** scene tại `res://scenes/hud/VitalityBar.tscn`

---

## 3. Tạo ShopItemCard.tscn (scene mới)

1. **File → New Scene**, root node là `PanelContainer`, đặt tên `ShopItemCard`
2. Cấu trúc:

```
ShopItemCard (PanelContainer)
├── VBoxContainer
│   ├── ItemIcon (TextureRect)         ← stretch_mode = Keep Aspect Centered
│   ├── NameLabel (Label)              ← horizontal_alignment = Center
│   └── PriceLabel (Label)             ← horizontal_alignment = Center
└── TapArea (Button)                   ← Flat=true, kích thước full card (anchors: Full Rect)
```

3. Gán script: chọn `ShopItemCard` → **Attach Script** → `res://scenes/shop/ShopItemCard.gd`
4. **Lưu** tại `res://scenes/shop/ShopItemCard.tscn`

---

## 4. Tạo ShopScene.tscn (scene mới)

1. **File → New Scene**, root node là `Control` (full screen), đặt tên `ShopScene`
2. Cấu trúc:

```
ShopScene (Control)
├── BackButton (Button)                ← text="← Quay lại", anchor top-left
├── TabContainer                       ← anchor: Full Rect với margin trên cho BackButton
│   ├── Consumables (ScrollContainer)  ← tên tab = "Tiêu hao"
│   │   └── GridContainer              ← columns=2 hoặc 3
│   ├── Seeds (ScrollContainer)        ← tên tab = "Hạt giống"
│   │   └── GridContainer
│   └── Decorations (ScrollContainer)  ← tên tab = "Trang trí"
│       └── GridContainer
├── LoadingSpinner (Control)           ← AnimationPlayer hoặc Label "Đang tải..."
└── ConfirmDialog (Panel)              ← hide() mặc định
    ├── ItemNameLabel (Label)
    ├── PriceLabel (Label)
    ├── ConfirmButton (Button)          ← text="Mua"
    └── CancelButton (Button)          ← text="Hủy"
```

3. Gán script: chọn `ShopScene` → **Attach Script** → `res://scenes/shop/ShopScene.gd`
4. **Lưu** tại `res://scenes/shop/ShopScene.tscn`

---

## 5. Đặt tên Tab trong TabContainer

Trong `ShopScene.tscn`, chọn từng tab con và đổi tên đúng thứ tự:
- Tab 0: `Tiêu hao` (scroll chứa Consumable items)
- Tab 1: `Hạt giống` (scroll chứa Seeds)
- Tab 2: `Trang trí` (scroll chứa Decorations — hiện "Sắp ra mắt")

ShopScene.gd dùng index 0/1/2 nên **thứ tự tab phải đúng**.

---

## 6. Smoke Test Checklist

Sau khi setup xong, chạy game và kiểm tra:

- [ ] **Currency HUD**: đăng nhập → số coin hiển thị đúng trên UserHUD
- [ ] **Currency cập nhật**: mua item trong shop → số coin giảm ngay lập tức
- [ ] **Vitality bar**: thanh sức sống hiển thị, đếm ngược đúng 1 giây / tick
- [ ] **Claim button**: enabled khi sẵn sàng, disabled sau khi nhấn
- [ ] **Vitality reward**: nhấn Nhận thưởng → toast hoặc log hiển thị rewardType + rewardAmount
- [ ] **Shop catalog**: mở shop → danh sách item load từ BE (không rỗng)
- [ ] **Mua item**: chọn item có đủ tiền → confirm dialog → mua → số coin trừ đúng
- [ ] **Không đủ tiền**: nút Mua bị disabled trong confirm dialog
- [ ] **Tab Trang trí**: hiển thị "Sắp ra mắt..." không thể mua
- [ ] **XP persist**: harvest hoa → thoát game → đăng nhập lại → XP không về 0
- [ ] **Level up**: tích đủ XP → level tăng, animation hiện

---

## 7. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|---|---|---|
| `_coin_label` = null, game crash | Chưa thêm node `CoinLabel` vào `UserHUD.tscn` | Thêm node Label đặt tên đúng `CoinLabel` |
| `_shop_btn` = null, không mở shop | Chưa thêm `ShopButton` vào `HUD.tscn` | Thêm Button đặt tên `ShopButton` |
| VitalityBar trắng, không có UI | Chưa tạo `VitalityBar.tscn` | Tạo scene theo bước 2 |
| Shop rỗng, không có item | Chưa có item trong DB hoặc `IsActive=false` | POST item qua Swagger hoặc chạy seed |
| `Cannot find node 'FillBar'` | Tên node sai trong VitalityBar.tscn | Kiểm tra tên node phải đúng hệt trong script |
| Vitality luôn "Sẵn sàng" | `VitalityReadyAt` null trong DB | Đây là đúng behavior — lần đầu chưa từng claim |
| XP vẫn về 0 sau restart | BE chưa chạy migration | Chạy `dotnet ef database update` trong eco-backend |
