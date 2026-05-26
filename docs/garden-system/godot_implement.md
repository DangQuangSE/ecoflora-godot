# Hướng dẫn triển khai Garden System trong Godot Editor

**Dành cho:** Người mới dùng Godot, chưa quen với Editor workflow
**Feature:** Garden System — Plant → Grow → Harvest loop

---

## 1. Kiểm tra Autoloads đã được đăng ký

Autoloads đã được tự động thêm vào `project.godot` trong quá trình cook. Hãy xác nhận:

1. Mở **Project → Project Settings** (menu bar trên cùng)
2. Chọn tab **Autoload**
3. Bạn phải thấy 4 entries:
   - `SceneTransition` → `res://autoloads/SceneTransition.gd`
   - `InteractionManager` → `res://autoloads/InteractionManager.gd`
   - `InventoryManager` → `res://autoloads/InventoryManager.gd`
   - `GardenManager` → `res://autoloads/GardenManager.gd`

Nếu thiếu, nhấn nút **+** (Add) ở góc phải, điền đường dẫn và tên autoload.

> **Lưu ý thứ tự quan trọng:** `InteractionManager` và `InventoryManager` phải đứng **trước** `GardenManager` vì `GardenManager._ready()` gọi đến hai manager kia.

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

Vị trí 8 ô đất được hardcode trong `autoloads/GardenManager.gd`:

```gdscript
const PLOT_POSITIONS: Array[Vector2] = [
    Vector2(80, 80),   Vector2(200, 80),
    Vector2(80, 200),  Vector2(200, 200),
    Vector2(80, 320),  Vector2(200, 320),
    Vector2(80, 440),  Vector2(200, 440),
]
```

Để xem bản đồ thực tế và điều chỉnh:

1. Chạy game (**F5** hoặc nút Play ▶)
2. Quan sát các ô đất màu nâu xuất hiện trong GardenScene
3. Nếu ô đất nằm ngoài vùng bản đồ hoặc đè lên nhau, tắt game và chỉnh lại các giá trị `Vector2` trong file `GardenManager.gd`
4. Dùng 2D Viewport trong Editor để đo vị trí: click vào TileMapLayer → xem kích thước trong Inspector

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
- [ ] 8 ô đất màu nâu xuất hiện trong bản đồ
- [ ] Player di chuyển được bằng joystick
- [ ] Đi đến gần ô đất (trong vòng ~80px) → popup xuất hiện với nút "Plant Flower"
- [ ] Click "Plant Flower" → xuất hiện nút "Sunflower" và "Rose"
- [ ] Click "Sunflower" → ô đất chuyển màu xanh lá, hiện "Lv.1"
- [ ] Click "Debug +XP" 2 lần → màu chuyển xanh đậm ("Lv.4") rồi vàng ("Lv.7")
- [ ] Khi "Lv.7", xuất hiện nút "Harvest" thay vì "Debug +XP"
- [ ] Click "Harvest" → ô đất trở về màu nâu, không còn label

---

## 7. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|-------------|-------------|----------|
| `Function "add_harvest_product" not found` | GardenManager._ready() chạy trước InventoryManager | Kiểm tra thứ tự Autoload trong Project Settings |
| Popup không xuất hiện khi đến gần ô đất | `proximity_radius` quá nhỏ hoặc player không được truyền vào `setup()` | Mở GardenManager.gd, tăng giá trị trong PLOT_POSITIONS cho gần hơn |
| 8 ô đất không nhìn thấy | Vị trí PLOT_POSITIONS nằm ngoài camera bounds | Chỉnh Vector2 trong `GardenManager.PLOT_POSITIONS` cho khớp với kích thước TileMap |
| `Null instance` khi click nút Plant | Plot.tscn thiếu node BtnPlant hoặc sai đường dẫn node | Kiểm tra scene tree của Plot.tscn khớp với `@onready` vars trong Plot.gd |
| Seed count không giảm sau khi trồng | Seed đã bị consume hết từ session trước (mock reset khi restart game) | Tắt và mở lại game để reset InventoryManager |
