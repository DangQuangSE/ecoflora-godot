# Hướng dẫn implement Map + Player trong Godot Editor

> Dành cho người mới dùng Godot. Đọc từng bước theo thứ tự, không bỏ qua.
> Code đã được tạo sẵn — bạn chỉ cần làm các bước cấu hình trong Editor.

---

## 1. Mở Project và kiểm tra cấu trúc

1. Mở Godot 4 → **Import** → chọn thư mục `flow-flora-godot` → **Import & Edit**
2. Ở tab **FileSystem** (góc dưới trái), kiểm tra cấu trúc đã có:
   ```
   res://
   ├── assets/
   │   ├── characters/
   │   │   ├── Pink_Monster_Idle.png
   │   │   └── Pink_Monster_Run.png
   │   └── tilesets/Tilemap/
   │       └── tilemap.png
   ├── autoloads/
   │   └── SceneTransition.gd
   └── scenes/
       ├── garden/GardenScene.tscn + GardenScene.gd
       ├── hud/DynamicJoystick.tscn + HUD.tscn
       ├── school/SchoolScene.tscn + SchoolScene.gd
       └── shared/Player.tscn + Portal.tscn
   ```
3. Nếu Godot báo lỗi màu đỏ ở tab **Errors**, đọc phần **7. Lỗi thường gặp** ở dưới.

---

## 2. Cài đặt SpriteFrames cho Player (dùng Pink Monster asset)

Player hiện đang dùng placeholder màu trắng. Làm theo các bước sau để thay bằng ảnh thật.

### 2.1 Mở Player scene
1. Double-click `res://scenes/shared/Player.tscn` trong FileSystem
2. Scene tree sẽ hiện ra:
   ```
   Player (CharacterBody2D)
   ├── AnimatedSprite2D
   ├── CollisionShape2D
   └── Camera2D
   ```

### 2.2 Tạo SpriteFrames mới
1. Click chọn node **AnimatedSprite2D** trong Scene tree
2. Nhìn sang panel **Inspector** (bên phải) → tìm trường **Sprite Frames**
3. Click vào trường đó → chọn **New SpriteFrames**
4. Một thanh **SpriteFrames editor** sẽ mở ở bottom panel

### 2.3 Cài đặt animation "idle"
1. Trong SpriteFrames editor, bạn thấy animation mặc định tên **"default"** — **đổi tên** thành `idle`:
   - Double-click tên "default" → gõ `idle` → Enter
2. Click nút **Add frames from sprite sheet** (biểu tượng lưới nhỏ ở góc phải panel)
3. Chọn file `res://assets/characters/Pink_Monster_Idle.png`
4. Cửa sổ **Select frames** mở ra:
   - Đặt **Horizontal** = số cột (đếm số frame trong ảnh, thường là 4)
   - Đặt **Vertical** = 1
   - Chọn tất cả các frame → **Add X frames**
5. Đảm bảo **Loop** = bật (biểu tượng vòng lặp)

### 2.4 Tạo 4 animation đi bộ
Lặp lại bước tương tự cho mỗi hướng. Click **+** (Add Animation) để tạo animation mới:

| Tên animation | File texture | Dùng frame nào |
|---------------|-------------|----------------|
| `walk_right` | `Pink_Monster_Run.png` | Tất cả frames |
| `walk_left` | `Pink_Monster_Run.png` | Tất cả frames (bật **Flip H** ở AnimatedSprite2D) |
| `walk_down` | `Pink_Monster_Run.png` | Tất cả frames |
| `walk_up` | `Pink_Monster_Run.png` | Tất cả frames |

> **Lưu ý walk_left**: Nếu chỉ có ảnh đi phải, chọn node **AnimatedSprite2D** → Inspector → bật **Flip H** khi animation `walk_left` đang chạy. Cách đơn giản hơn: dùng cùng frames với `walk_right`, code sẽ xử lý flip sau.

### 2.5 Lưu scene
Nhấn **Ctrl+S** để lưu Player.tscn.

---

## 3. Cài đặt TileSet cho GardenScene

Đây là bước quan trọng nhất — thiếu bước này thì player sẽ đi xuyên tường.

### 3.1 Mở GardenScene
Double-click `res://scenes/garden/GardenScene.tscn`

Scene tree:
```
GardenScene (Node2D)
├── TileMapLayer
├── Player  ← instance từ Player.tscn
├── HUD     ← instance từ HUD.tscn
└── Portal  ← instance từ Portal.tscn
```

### 3.2 Tạo TileSet
1. Click chọn node **TileMapLayer**
2. Inspector → trường **Tile Set** → click **[empty]** → chọn **New TileSet**
3. TileSet resource được tạo, Inspector hiện thêm các trường

### 3.3 Cài đặt tile size
Inspector → **Tile Size** → đặt `16 x 16` (hoặc kích thước tile của tilemap.png bạn dùng)

### 3.4 Thêm Atlas Source (ảnh tileset)
1. Ở bottom panel, tab **TileSet** vừa mở ra
2. Click nút **+** (Add source) → chọn **Atlas**
3. Kéo file `res://assets/tilesets/Tilemap/tilemap.png` từ FileSystem vào ô **Texture**
4. Godot sẽ tự chia lưới tile — kiểm tra lưới trông đúng không

### 3.5 Thêm Physics Layer (để có collision)
1. Vẫn đang ở Inspector của TileMapLayer → kéo xuống phần **Physics Layers**
2. Click **Add Element** → một Physics Layer được thêm (Layer 0)
3. Đặt **Collision Layer** = 1, **Collision Mask** = 1

### 3.6 Vẽ collision cho từng tile
1. Tab **TileSet** (bottom) → click vào tile bất kỳ
2. Bên phải hiện **Inspector** của tile đó → tab **Physics**
3. Click **Add Polygon** → vẽ hình collision cho tile đó (thường là hình chữ nhật phủ toàn ô)
4. Lặp lại cho tất cả tile "solid" (tường, rào)

### 3.7 Vẽ map trong GardenScene
1. Click chọn node **TileMapLayer** trong Scene tree
2. Tab **TileMap** xuất hiện ở bottom panel
3. Chọn tile muốn vẽ từ palette → click/kéo chuột trên viewport để paint
4. Vẽ ít nhất một vòng border (tường bao quanh) để giữ player không ra khỏi map

### 3.8 Lưu scene
**Ctrl+S**

---

## 4. Cài đặt SchoolScene (làm tương tự)

Mở `res://scenes/school/SchoolScene.tscn` → lặp lại toàn bộ **Mục 3** nhưng:
- Có thể dùng màu khác hoặc tileset khác để phân biệt với GardenScene
- Portal trong SchoolScene đã có `target_scene = "res://scenes/garden/GardenScene.tscn"` (không cần đổi)

---

## 5. Kiểm tra Portal target_scene

1. Mở `GardenScene.tscn`
2. Click node **Portal** trong Scene tree
3. Inspector → trường **Target Scene** phải là:
   ```
   res://scenes/school/SchoolScene.tscn
   ```
4. Mở `SchoolScene.tscn` → Portal → Target Scene phải là:
   ```
   res://scenes/garden/GardenScene.tscn
   ```

Nếu trống → gõ đường dẫn vào hoặc drag file từ FileSystem vào ô đó.

---

## 6. Kiểm tra Project Settings

1. Menu **Project → Project Settings**
2. Tab **Application → Run**:
   - **Main Scene** phải là `res://scenes/garden/GardenScene.tscn`
3. Tab **Display → Window → Handheld**:
   - **Orientation** = Portrait
4. Tab **Globals (AutoLoad)**:
   - Phải có dòng `SceneTransition` → `res://autoloads/SceneTransition.gd`

Nếu thiếu AutoLoad → click **+** → Name: `SceneTransition`, Path: chọn file gd → **Add**.

---

## 7. Smoke Test Checklist

Chạy game bằng nút **▶ Play** (F5) và kiểm tra từng mục:

- [ ] GardenScene mở đầu tiên, thấy map và player
- [ ] Nhấn giữ ở vùng **dưới** màn hình ≥ 1 giây → joystick xuất hiện
- [ ] Kéo joystick → player di chuyển đúng hướng
- [ ] Nhấc tay → player dừng, joystick ẩn
- [ ] Nhấn ở vùng **trên** màn hình → joystick KHÔNG xuất hiện
- [ ] Player đi vào Portal → màn hình fade đen → SchoolScene load
- [ ] Trong SchoolScene, đi vào Portal → quay về GardenScene
- [ ] Player KHÔNG đi xuyên tile solid (cần làm Mục 3.5–3.7 trước)
- [ ] Camera theo player, không ra ngoài biên map (cần tile có data)

---

## 8. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|-------------|-------------|----------|
| Lỗi `Invalid get index 'tile_set'` | TileMapLayer chưa có TileSet | Làm Mục 3.2 |
| Player không nhìn thấy (invisible) | AnimatedSprite2D chưa có SpriteFrames | Làm Mục 2 |
| Joystick không hiện sau 1 giây | Đang nhấn ở vùng trên 60% màn hình | Nhấn ở vùng dưới (bottom 40%) |
| Màn hình không fade khi vào Portal | SceneTransition chưa đăng ký autoload | Kiểm tra Project Settings → AutoLoad |
| Portal không trigger | `target_scene` trống | Làm Mục 5 |
| Player đi xuyên tường | Tile chưa có Physics Polygon | Làm Mục 3.5–3.6 |
| Camera bị giật hoặc không smooth | `position_smoothing_enabled` chưa bật | Camera2D → Inspector → bật Position Smoothing |
| Lỗi đỏ `Class 'Player' not found` | Godot chưa index script mới | Đóng và mở lại Project |
| Scene transition loop vô hạn | Portal của 2 scene trỏ vào nhau sai | Kiểm tra target_scene ở cả 2 Portal |

---

> **Tip cho người mới**: Khi gặp lỗi đỏ ở Errors tab, click vào dòng lỗi — Godot sẽ nhảy đến đúng dòng code gây lỗi. Hầu hết lỗi Inspector là do chưa gán resource (null reference).
