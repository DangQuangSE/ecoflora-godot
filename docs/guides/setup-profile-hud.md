# Hướng dẫn thiết lập UI Profile HUD

Hướng dẫn này mô tả cách xây dựng phần hiển thị thông tin người chơi (tên, level, XP, currency) theo kỹ thuật **"background trick"** — dùng Sprite2D làm nền trang trí, Control node thật đè lên để hiển thị dữ liệu.

---

## Kết quả cuối cùng

```
UserHUD (Panel)
├── PfFrame   (Sprite2D)  ← khung ngoài, chỉ trang trí
├── PfName    (Sprite2D)  ← nền vùng tên, chỉ trang trí
├── PfExp     (Sprite2D)  ← nền thanh XP, chỉ trang trí
├── PfLevel   (Sprite2D)  ← nền ô level, chỉ trang trí
├── AvatarRect (Panel)    ← ô avatar, tương tác được
├── NameLabel  (Label)    ← tên người chơi (data thật)
├── LevelLabel (Label)    ← số level (data thật)
├── XPBar    (ProgressBar) ← thanh XP (data thật)
├── CoinIcon  (TextureRect) ← icon coin
└── CoinLabel  (Label)    ← số currency (data thật)
```

---

## Bước 1 — Chuẩn bị asset

Đặt tất cả PNG vào `res://assets/profile/`:

```
assets/profile/
    pf_frame.png     ← khung gỗ ngoài cùng (toàn bộ widget)
    pf_name.png      ← dải nền vùng tên (phần phải)
    pf_exp.png       ← nền thanh XP
    pf_level.png     ← nền ô hiển thị số level
```

Drag từng file vào **FileSystem panel** trong Godot Editor để tạo `.import` tự động. **Không** copy thẳng vào folder mà không mở Godot — asset sẽ không load được khi chạy game.

---

## Bước 2 — Tạo scene và đặt Sprite2D background

1. Mở `res://scenes/hud/UserHUD.tscn`
2. Root node là **Panel**, đặt tên `UserHUD`, gán script `UserHUD.gd`
3. Tạo 4 **Sprite2D** con (Add Child Node → Sprite2D):

| Node name | Texture             | Vai trò        |
|-----------|---------------------|----------------|
| `PfFrame` | `pf_frame.png`      | Khung ngoài    |
| `PfName`  | `pf_name.png`       | Nền vùng tên   |
| `PfExp`   | `pf_exp.png`        | Nền thanh XP   |
| `PfLevel` | `pf_level.png`      | Nền ô level    |

4. Với mỗi Sprite2D: kéo texture từ FileSystem vào ô **Texture** trong Inspector
5. Dùng **Move Tool (W)** trong 2D viewport để kéo từng sprite vào đúng vị trí mong muốn
6. Dùng **Scale** để thu/phóng cho vừa khung

> **Tip:** Bật `Region` trong Inspector của Sprite2D nếu chỉ muốn dùng một phần của ảnh lớn.

---

## Bước 3 — Thêm Control node lên trên

Tạo các node **sau** (bên dưới) các Sprite2D trong scene tree — node sau sẽ vẽ đè lên node trước:

### AvatarRect (Panel)
- **Node type:** Panel
- **Inspector → Theme Overrides → Styles → panel:** tạo `StyleBoxFlat`
  - `bg_color`: `Color(0.35, 0.55, 0.88, 1)` (xanh dương)
  - `corner_radius`: 10 (tất cả 4 góc)
- `mouse_filter = Ignore`
- Kéo vào đúng vùng avatar trong PfFrame

### NameLabel (Label)
- Text mặc định: `"Name"` (sẽ được thay bằng username thật khi runtime)
- `font_color`: `Color(0.28, 0.14, 0.04, 1)` — nâu đậm, dễ đọc trên nền sáng
- Kéo vào vùng PfName

### LevelLabel (Label)
- Text mặc định: `"1"`
- `font_color`: `Color(0.95, 0.82, 0.1, 1)` — vàng gold
- `horizontal_alignment = Center`
- Kéo vào vùng PfLevel (chỉ hiện số, vì PfLevel sprite đã có chữ "Lv." trong ảnh)

### XPBar (ProgressBar)
- `show_percentage = false`
- `max_value = 200` (sẽ bị override lúc runtime)
- **Theme Overrides → Styles → background:** `StyleBoxTexture` → chọn `pf_exp.png`
- **Theme Overrides → Styles → fill:** `StyleBoxFlat` với màu xanh da trời `Color(0.2, 0.65, 0.95, 1)`
- Kéo đè lên PfExp sprite

### CoinIcon (TextureRect)
- Texture: `res://assets/icon/coin.png`
- `expand_mode = Ignore Size`, `stretch_mode = Keep Aspect Centered`
- Đặt bên dưới frame, bên trái CoinLabel

### CoinLabel (Label)
- Text mặc định: `"0"`
- `font_color`: `Color(1.0, 0.88, 0.3, 1)` — vàng
- Đặt cạnh CoinIcon

---

## Bước 4 — Canh chỉnh vị trí chính xác

Sau khi kéo gần đúng bằng Move Tool, chọn từng node → **Inspector → Layout → offset_left / offset_top / offset_right / offset_bottom** để tinh chỉnh pixel-perfect.

**Thứ tự node trong scene tree rất quan trọng:**
- Sprite2D backgrounds phải ở **trên** (liệt kê trước)
- Control nodes phải ở **dưới** (liệt kê sau)

Kéo reorder trong Scene panel nếu sai thứ tự.

---

## Bước 5 — Gán script và wire @onready

Trong `scenes/hud/UserHUD.gd`, đảm bảo các dòng này tồn tại:

```gdscript
@onready var _avatar: Control      = $AvatarRect
@onready var _name_label: Label    = $NameLabel
@onready var _level_label: Label   = $LevelLabel
@onready var _xp_bar: ProgressBar  = $XPBar
@onready var _coin_label: Label    = $CoinLabel
```

Hàm `_refresh()` cập nhật tất cả từ `UserManager`:

```gdscript
func _refresh() -> void:
    var p := UserManager.get_profile()
    if is_instance_valid(_name_label) and p.username != "":
        _name_label.text = p.username
    _level_label.text = "%d" % p.level
    _xp_bar.max_value = p.xp_to_next_level()
    _xp_bar.value     = p.current_xp
    if is_instance_valid(_coin_label):
        _coin_label.text = str(p.currency)
```

---

## Bước 6 — Kết nối dữ liệu từ backend

### domain/UserProfile.gd
Thêm field `username`:
```gdscript
var username: String = ""
var level: int = 1
var currency: int = 0
# ...
```

### services/UserService.gd — hàm parse_profile()
Map thêm `username` từ JSON response:
```gdscript
p.username = str(data.get("username", ""))
```

---

## Bước 7 — Test với admin API

Dùng admin account để set data test cho user:

```powershell
# 1. Login lấy token
$r = Invoke-RestMethod -Uri "http://localhost:5226/api/auth/login" `
     -Method POST -ContentType "application/json" `
     -Body '{"account":"admin@flowflora.dev","password":"Admin123!"}'
$token = $r.data.accessToken

# 2. Update level + currency cho player test
Invoke-RestMethod -Uri "http://localhost:5226/api/user/{userId}" `
     -Method PUT `
     -Headers @{Authorization="Bearer $token"} `
     -ContentType "application/json" `
     -Body '{"level":3,"currency":500}'
```

Thay `{userId}` bằng ID thật từ `GET /api/user`.

Sau khi set xong, chạy game và login bằng account test — profile HUD sẽ hiện:
- **NameLabel** → username từ DB
- **LevelLabel** → số level
- **XPBar** → XP hiện tại trong level
- **CoinLabel** → số currency

---

## Lưu ý quan trọng

| Vấn đề | Nguyên nhân | Cách fix |
|--------|-------------|----------|
| Asset không load | Chưa import vào Godot | Drag PNG vào FileSystem panel |
| Text hiển thị sai vị trí | Sprite2D ở dưới Control trong scene tree | Kéo Sprite2D lên trên Control |
| Username vẫn là "Name" | `username` chưa được parse từ API | Thêm `p.username = str(data.get("username",""))` trong `UserService.parse_profile()` |
| LevelLabel hiện "Lv.3" thay vì "3" | Format string sai trong `.gd` | Dùng `"%d" % p.level` thay vì `"Lv.%d"` (PfLevel sprite đã có chữ "Lv." trong ảnh) |
| XPBar không fill | `max_value` chưa được set | Đảm bảo `_xp_bar.max_value = p.xp_to_next_level()` được gọi trong `_refresh()` |
