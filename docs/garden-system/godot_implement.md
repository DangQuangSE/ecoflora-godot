# Hướng dẫn triển khai Garden System trong Godot Editor

**Dành cho:** Người mới dùng Godot, chưa quen với Editor workflow
**Feature:** Garden System — Plant → Grow → Harvest loop

---

## 1. Kiểm tra Autoloads đã được đăng ký

Autoloads đã được tự động thêm vào `project.godot` trong quá trình cook. Hãy xác nhận:

1. Mở **Project → Project Settings** (menu bar trên cùng)
2. Chọn tab **Autoload**
3. Bạn phải thấy 5 entries:
   - `SceneTransition` → `res://autoloads/SceneTransition.gd`
   - `InteractionManager` → `res://autoloads/InteractionManager.gd`
   - `InventoryManager` → `res://autoloads/InventoryManager.gd`
   - `GardenManager` → `res://autoloads/GardenManager.gd`
   - `ZoneManager` → `res://autoloads/ZoneManager.gd`

Nếu thiếu, nhấn nút **+** (Add) ở góc phải, điền đường dẫn và tên autoload.

> **Lưu ý thứ tự quan trọng:** `InteractionManager` và `InventoryManager` phải đứng **trước** `GardenManager` vì `GardenManager._ready()` gọi đến hai manager kia. `ZoneManager` phải đứng **sau** `UserManager` để xác định zone unlock dựa trên user XP.

---

## 2. Mở và kiểm tra GardenScene

1. Trong **FileSystem** panel (góc dưới trái), tìm `res://scenes/garden/GardenScene.tscn`
2. Double-click để mở scene
3. Scene tree (góc trên trái) phải trông như sau:

```
GardenScene (Node2D)
├── TileMapLayer
├── Player
├── HUD
└── Portal
```

Plot nodes **không có** trong scene tree khi xem trong Editor — chúng được spawn động qua code trong `_ready()`. Điều này là bình thường.

---

## 3. Điều chỉnh vị trí các ô đất (Plot Positions)

Vị trí 16 ô đất được hardcode trong `autoloads/GardenManager.gd` dưới dạng lưới 4×4:

```gdscript
const PLOT_POSITIONS: Array[Vector2] = [
    Vector2(80, 80),   Vector2(160, 80),   Vector2(240, 80),   Vector2(320, 80),
    Vector2(80, 160),  Vector2(160, 160),  Vector2(240, 160),  Vector2(320, 160),
    Vector2(80, 240),  Vector2(160, 240),  Vector2(240, 240),  Vector2(320, 240),
    Vector2(80, 320),  Vector2(160, 320),  Vector2(240, 320),  Vector2(320, 320),
]
```

Để xem bản đồ thực tế và điều chỉnh:

1. Chạy game (**F5** hoặc nút Play ▶)
2. Quan sát các ô đất màu nâu xuất hiện trong GardenScene
3. Một số ô đất có thể bị phủ bởi **CloudOverlay** (mây) nếu chúng nằm trong zone chưa được unlock
4. Nếu ô đất nằm ngoài vùng bản đồ hoặc đè lên nhau, tắt game và chỉnh lại các giá trị `Vector2` trong file `GardenManager.gd`
5. Dùng 2D Viewport trong Editor để đo vị trí: click vào TileMapLayer → xem kích thước trong Inspector

---

## 4. Kiểm tra Plot.tscn (nếu cần chỉnh UI)

1. Mở `res://scenes/garden/Plot.tscn` trong FileSystem
2. Scene tree phải trông như sau:

```
Plot (Node2D)
├── PlotSprite (ColorRect) — ô vuông 64×64
├── StageLabel (Label)     — hiện "Lv.X"
└── Popup (CanvasLayer)
    └── PopupPanel (Panel)
        └── VBox (VBoxContainer)
            ├── BtnPlant (Button)       "Plant Flower"
            ├── SeedOptions (VBoxContainer)
            │   ├── BtnSunflower (Button) "Sunflower"
            │   └── BtnRose (Button)     "Rose"
            ├── BtnHarvest (Button)     "Harvest"
            └── BtnAddXP (Button)       "Debug +XP"
```

Để điều chỉnh kích thước/vị trí popup trên màn hình:
1. Click vào **PopupPanel** trong scene tree
2. Trong **Inspector** panel, tìm mục **Anchor** và **Offset**
3. Các giá trị `anchor_*` (0.0 → 1.0) xác định vị trí tỉ lệ với kích thước màn hình
4. Thay đổi `anchor_top` và `anchor_bottom` để di chuyển popup lên/xuống

---

## 5. Kiểm tra Script đã gán đúng

| Node | Script cần gán |
|------|---------------|
| Plot (Plot.tscn) | `res://scenes/garden/Plot.gd` |
| GardenScene | `res://scenes/garden/GardenScene.gd` |

Cách kiểm tra: click vào node → Inspector → nhìn vào mục **Script** (biểu tượng cuộn giấy). Nếu chưa có script, drag file `.gd` từ FileSystem vào ô Script.

---

## 6. Smoke Test Checklist

Chạy game (**F5**) và kiểm tra từng bước:

- [ ] Game khởi động tại GardenScene, không có lỗi màu đỏ trong **Output** panel
- [ ] 16 ô đất màu nâu xuất hiện trong bản đồ dưới dạng lưới 4×4
- [ ] Một số ô đất ở phía dưới/phải được phủ bởi **CloudOverlay** (hình mây) nếu zone chưa unlock
- [ ] Player di chuyển được bằng joystick
- [ ] Đi đến gần ô đất không bị khóa (trong vòng ~80px) → popup xuất hiện với nút "Plant Flower"
- [ ] Cố gắng click nút "Plant Flower" trên ô đất bị khóa (có mây) → không có phản ứng (guard check)
- [ ] Click "Plant Flower" trên ô đất mở → xuất hiện nút "Sunflower" và "Rose"
- [ ] Click "Sunflower" → ô đất chuyển màu xanh lá, hiện "Lv.1"
- [ ] Click "Debug +XP" 2 lần → màu chuyển xanh đậm ("Lv.4") rồi vàng ("Lv.7")
- [ ] Khi "Lv.7", xuất hiện nút "Harvest" thay vì "Debug +XP"
- [ ] Click "Harvest" → ô đất trở về màu nâu, không còn label
- [ ] Tích lũy đủ user XP để unlock zone mới → CloudOverlay biến mất từ ô đất zone đó, hiển thị **UnlockBanner** thông báo

---

## 7. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|-------------|-------------|----------|
| `Function "add_harvest_product" not found` | GardenManager._ready() chạy trước InventoryManager | Kiểm tra thứ tự Autoload trong Project Settings |
| ZoneManager không tìm thấy | ZoneManager chưa được đăng ký trong Autoload hoặc thứ tự sai | Kiểm tra Project Settings → Autoload: ZoneManager phải có, và UserManager phải ở trước |
| CloudOverlay không hiện | Ô đất zone bị khóa không được đăng ký với ZoneManager | Kiểm tra GardenScene.gd: `_spawn_zone_overlays()` phải được gọi trong `_ready()` |
| Plot bị khóa nhưng không có mây | Plot.gd thiếu guard check `if is_plot_locked: return` trong `on_popup_btn_plant_pressed()` | Kiểm tra Plot.gd có kiểm tra `is_plot_locked` trước khi cho phép trồng |
| Popup không xuất hiện khi đến gần ô đất | `proximity_radius` quá nhỏ hoặc player không được truyền vào `setup()` | Mở GardenManager.gd, tăng giá trị trong PLOT_POSITIONS cho gần hơn |
| 16 ô đất không nhìn thấy | Vị trí PLOT_POSITIONS nằm ngoài camera bounds | Chỉnh Vector2 trong `GardenManager.PLOT_POSITIONS` cho khớp với kích thước TileMap |
| `Null instance` khi click nút Plant | Plot.tscn thiếu node BtnPlant hoặc sai đường dẫn node | Kiểm tra scene tree của Plot.tscn khớp với `@onready` vars trong Plot.gd |
| Seed count không giảm sau khi trồng | Seed đã bị consume hết từ session trước (mock reset khi restart game) | Tắt và mở lại game để reset InventoryManager |
| UnlockBanner không hiện khi unlock zone | GardenScene.tscn thiếu notification queue hoặc ZoneManager.on_zone_unlocked signal không kết nối | Kiểm tra GardenScene.gd có `_on_zone_unlocked()` callback |

---

## 8. Hệ thống Zone (Zone Unlock System)

### Tổng quan

Hệ thống Zone cho phép chia khu vườn thành các vùng có thể mở khóa dần khi người chơi tích lũy đủ kinh nghiệm. Mỗi zone có:
- **ZoneDefinition**: Xác định yêu cầu XP để unlock zone
- **CloudOverlay**: Hiển thị mây để che phủ ô đất bị khóa
- **UnlockBanner**: Thông báo khi zone được unlock

### ZoneManager

`ZoneManager` là autoload quản lý trạng thái mở khóa zone. Nó theo dõi XP của người dùng và tự động mở khóa zone khi đạt ngưỡng.

Kiểm tra: **Project Settings → Autoload** → phải có `ZoneManager` đăng ký.

### CloudOverlay.tscn

Cảnh CloudOverlay là một Node2D hiển thị hình ảnh mây phủ lên các ô đất bị khóa.

**Scene tree:**
```
CloudOverlay (Node2D)
├── AnimatedSprite2D  ← animation mây động
└── CollisionShape2D  ← click để tương tác (tùy chọn)
```

Vị trí CloudOverlay được đặt bởi `GardenScene._spawn_zone_overlays()` tương ứng với từng ô đất.

### UnlockBanner.tscn

Cảnh thông báo hiển thị khi một zone mới được mở khóa.

**Scene tree:**
```
UnlockBanner (CanvasLayer)
├── Panel            ← nền banner
│   └── VBoxContainer
│       └── Label   ← "Zone X Unlocked!"
└── AnimationPlayer ← fade in/out
```

### Quy trình mở khóa zone (Unlocking Flow)

1. **GardenScene._ready()** gọi `_spawn_zone_overlays()` để đặt CloudOverlay cho từng ô đất bị khóa
2. **UserManager** theo dõi user XP
3. **ZoneManager** lắng nghe signal `on_user_xp_changed` từ UserManager
4. Khi user XP đạt ngưỡng zone mới:
   - ZoneManager đánh dấu zone là unlocked
   - ZoneManager phát signal `on_zone_unlocked(zone_id)`
   - GardenScene nhận signal và:
     - Xóa CloudOverlay tương ứng từ scene
     - Hiển thị UnlockBanner với animation
5. Các ô đất zone đó bây giờ có thể trồng được

### Cấu hình Zone

Zone definitions được định nghĩa trong code hoặc mock service. Mỗi zone có:

```
zone_id:        "zone_0", "zone_1", "zone_2", "zone_3"
xpRequirement:  100, 300, 600, 1000 (ví dụ)
plotIndices:    [0-3], [4-7], [8-11], [12-15] (gán ô đất cho zone)
```

Để thay đổi yêu cầu XP, chỉnh sửa trong `autoloads/ZoneManager.gd` hoặc `services/MockGardenService.gd`.
