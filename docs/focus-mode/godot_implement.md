# Hướng dẫn triển khai Focus Mode trong Godot Editor

**Dành cho:** Người mới dùng Godot, chưa quen với Editor workflow
**Feature:** Focus Mode — học tập có tính giờ, phát hiện vi phạm, thưởng/phạt XP cây

---

## 1. Xác nhận FocusManager đã được đăng ký

Code đã tự động thêm `FocusManager` vào `project.godot`. Hãy xác nhận:

1. Mở **Project → Project Settings** (menu bar trên cùng)
2. Chọn tab **Autoload**
3. Bạn phải thấy đủ 7 entries theo đúng thứ tự:
   - `SceneTransition`
   - `InteractionManager`
   - `InventoryManager`
   - `GardenManager`
   - `UserManager`
   - `ZoneManager`
   - `FocusManager` → `res://autoloads/FocusManager.gd` ← **mới thêm**

> **Lưu ý thứ tự:** `FocusManager` phải đứng **sau** `ZoneManager`. Nếu thứ tự sai, game sẽ lỗi khi khởi động vì `FocusManager._ready()` gọi `GardenManager` — manager này phải đã load xong trước.

Nếu thiếu `FocusManager`: nhấn nút **+** ở góc phải, điền:
- **Path:** `res://autoloads/FocusManager.gd`
- **Name:** `FocusManager`

---

## 2. Tắt bypass_violation_detection khi test trên PC

`FocusManager` có một `@export` đặc biệt để test trên máy tính:

1. Vào **Project → Project Settings → Autoload**
2. Tìm `FocusManager` trong danh sách
3. Nhấn biểu tượng **✎ (Edit)** hoặc mở scene chứa FocusManager
4. **Cách dễ hơn:** Khi chạy game trong Editor, mở tab **Remote** (góc trên trái, cạnh "Local") → tìm node `FocusManager` → Inspector → bật **Bypass Violation Detection = true**

> **Tại sao cần?** Khi test trên PC, mỗi lần bạn Alt-Tab sang cửa sổ khác sẽ bị tính là 1 vi phạm. Với `bypass_violation_detection = true`, tính năng phát hiện vi phạm bị tắt hoàn toàn — bạn có thể test luồng hoàn thành session mà không lo bị ngắt.

---

## 3. Mở và kiểm tra SchoolScene

1. Trong **FileSystem** panel, tìm `res://scenes/school/SchoolScene.tscn`
2. Double-click để mở
3. Scene tree phải trông như sau:

```
SchoolScene (Node2D) [SchoolScene.gd]
├── TileMapLayer          ← bỏ trống hoặc vẽ tile nền trường
├── Player                ← nhân vật, spawn tại position = (160, 280)
├── HUD                   ← joystick di chuyển
├── PortalToGarden        ← đi về GardenScene, position = (160, 80)
└── PortalToClassroom     ← đi vào ClassroomScene, position = (360, 300)
```

### 3.1 Điều chỉnh vị trí Portal

Hai portal là các Area2D vô hình — bạn cần đặt chúng đúng chỗ trên map:

1. Chọn node **PortalToGarden** → Inspector bên phải → **Position**: điều chỉnh để trùng với vị trí "cổng ra" trên background
2. Chọn node **PortalToClassroom** → Inspector → **Position**: điều chỉnh để trùng với "cửa vào lớp học"

> Để thấy CollisionShape2D của portal khi chạy: **Debug → Visible Collision Shapes** (bật khi play)

### 3.2 Thêm background campus

1. Chọn **TileMapLayer** hoặc tạo node **Sprite2D** mới (nhấn **+** trong scene tree)
2. Nếu dùng Sprite2D: đặt tên `Background`, kéo PNG campus từ FileSystem vào trường **Texture** trong Inspector
3. Đặt **Z Index = -2** (Inspector → CanvasItem → Ordering → Z Index) để background ở phía sau

---

## 4. Mở và kiểm tra ClassroomScene

1. Trong **FileSystem**, tìm `res://scenes/school/ClassroomScene.tscn`
2. Double-click để mở
3. Scene tree phải trông như sau:

```
ClassroomScene (Node2D) [ClassroomScene.gd]
├── Background (ColorRect)   ← placeholder màu nâu, z_index=-2
├── Player                   ← nhân vật, spawn tại (360, 700)
├── HUD                      ← joystick
├── ClassroomTrigger (Area2D)← vùng kích hoạt FocusTimerUI, position = (360, 400)
│   └── CollisionShape2D     ← hình chữ nhật 200×80
└── PortalToSchool           ← đi về SchoolScene, position = (360, 880)
```

### 4.1 Kiểm tra vị trí ClassroomTrigger

**Quan trọng:** Player spawn tại `(360, 700)` và ClassroomTrigger ở `(360, 400)`. Player phải đi từ dưới lên mới chạm vào trigger — nếu Player spawn chồng lên trigger, FocusTimerUI sẽ mở ngay khi vào scene.

1. Bật **Debug → Visible Collision Shapes** trước khi chạy để thấy hình chữ nhật trigger
2. Nếu Player spawn chồng trigger: chọn **Player** → Inspector → **Position** → đổi Y lên cao hơn (ví dụ `700 → 780`)

### 4.2 Thay thế placeholder background

Background hiện là `ColorRect` màu nâu (placeholder). Để thay bằng ảnh lớp học:
1. Click chọn node **Background**
2. Trong Inspector → **Script** → đổi type thành `Sprite2D` (hoặc tạo Sprite2D node mới rồi xóa ColorRect cũ)
3. Kéo PNG ảnh lớp học vào trường **Texture**

---

## 5. Kiểm tra FocusTimerUI (tùy chọn)

FocusTimerUI được spawn bằng code khi player bước vào `ClassroomTrigger` — bạn **không thấy** nó trong scene tree khi mở ClassroomScene trong Editor. Điều này bình thường.

Để xem trước giao diện:
1. Trong **FileSystem**, mở `res://scenes/school/FocusTimerUI.tscn`
2. Scene tree:

```
FocusTimerUI (CanvasLayer, layer=10) [FocusTimerUI.gd]
└── Panel
    ├── SetupPanel (visible=true)
    │   └── SetupBox (VBoxContainer)
    │       ├── TitleLabel      "Chọn thời gian tập trung"
    │       ├── DurationSlider  (5–120 phút, mặc định 25)
    │       ├── DurationLabel   "25 phút"
    │       └── StartButton     "Bắt đầu"
    ├── RunningPanel (visible=false)
    │   └── RunningBox (VBoxContainer)
    │       ├── CountdownLabel  "25:00"
    │       ├── ViolationLabel  "Vi phạm: 0 / 3"
    │       └── CancelButton    "Hủy"
    └── ResultPanel (visible=false)
        └── ResultBox (VBoxContainer)
            ├── ResultLabel     (hiện kết quả: "+X XP" hoặc "-20 XP")
            └── ReturnButton    "Quay lại trường"
```

### 5.1 Điều chỉnh thời gian mặc định

Để đổi thời gian focus mặc định từ 25 phút sang giá trị khác:
1. Mở `FocusTimerUI.tscn`
2. Chọn node `DurationSlider`
3. Inspector → **Value** → đổi thành giá trị bạn muốn (phải nằm trong 5–120, bội số của 5)

---

## 6. Kiểm tra Portal từ GardenScene sang SchoolScene

Portal đã được cấu hình sẵn trong GardenScene:

1. Mở `res://scenes/garden/GardenScene.tscn`
2. Trong scene tree, tìm node **Portal**
3. Inspector → **Target Scene** phải là `res://scenes/school/SchoolScene.tscn`
4. **Disabled** = false (đã bật)

Nếu bạn muốn tắt portal trong lúc test garden:
- Inspector → **Disabled** = true

---

## 7. Smoke Test Checklist

Chạy game và kiểm tra từng bước:

- [ ] **Garden → School:** Đi đến vị trí Portal trong GardenScene → màn hình fade → hiện SchoolScene
- [ ] **Di chuyển trong trường:** Joystick hoạt động, player di chuyển được trong SchoolScene
- [ ] **School → Classroom:** Đi đến PortalToClassroom → fade → hiện ClassroomScene
- [ ] **Trigger FocusTimerUI:** Đi player vào vùng ClassroomTrigger → FocusTimerUI xuất hiện với SetupPanel
- [ ] **Chọn thời gian:** Kéo DurationSlider → label cập nhật đúng (ví dụ: "30 phút")
- [ ] **Bắt đầu session:** Nhấn "Bắt đầu" → SetupPanel ẩn, RunningPanel hiện với countdown đếm ngược
- [ ] **Hoàn thành session:** Để timer chạy hết (test với 1 phút) → ResultPanel hiện "+1 XP cho tất cả cây"
- [ ] **Quay lại:** Nhấn "Quay lại trường" → fade về SchoolScene
- [ ] **Kiểm tra XP cây:** Quay về GardenScene → tap vào cây đang trồng → XP phải tăng đúng
- [ ] **Hủy session:** Bắt đầu session → nhấn "Hủy" → FocusTimerUI đóng, player vẫn trong lớp
- [ ] **Exit mid-session:** Bắt đầu session → đi đến PortalToSchool → fade về SchoolScene → FocusManager không còn ACTIVE (không bị kẹt)

---

## 8. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|---|---|---|
| FocusTimerUI mở ngay khi vào ClassroomScene | Player spawn chồng lên ClassroomTrigger | Chọn Player → Inspector → Position → tăng Y (ví dụ 700 → 800) |
| Alt-Tab làm tăng violation count khi test trên PC | `bypass_violation_detection = false` (mặc định) | Mở Remote tab khi play → FocusManager → bật Bypass Violation Detection |
| Portal vào trường không hoạt động | `disabled = true` trên Portal node trong GardenScene | Chọn Portal → Inspector → Disabled = false |
| Countdown hiện "00:00" ngay khi bắt đầu | DurationSlider value = 0 | Chọn DurationSlider → Inspector → Value = 25 |
| "Identifier 'FocusManager' not declared" | FocusManager chưa có trong Project Settings → Autoload | Thêm như hướng dẫn mục 1 |
| Không thấy ClassroomTrigger ở đâu khi chạy | CollisionShape vô hình mặc định | Bật **Debug → Visible Collision Shapes** trước khi nhấn Play |
| Cây không nhận XP sau focus session | Plot đang ở trạng thái `is_pending_sync = true` khi session kết thúc | Chờ 1 frame rồi chạy lại; hoặc không tương tác với cây ngay trước khi session kết thúc |
| FocusManager lỗi "method not found" | Script chưa được load đúng | Restart Godot Editor, kiểm tra lại Autoload order |
