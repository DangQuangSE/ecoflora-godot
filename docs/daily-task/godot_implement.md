# Hướng dẫn thiết lập Godot Editor — Daily Task System

## 1. Mở Scene và kiểm tra cấu trúc Node

### HUD.tscn — thêm DailyTaskButton
1. Mở `res://scenes/hud/HUD.tscn`
2. Trong Scene tree, chọn node gốc `HUD (Control)`
3. Thêm node con: **Add Child Node → Button**, đặt tên `DailyTaskButton`
   - Inspector: `Text` = `📋` hoặc gán icon texture tùy ý
   - Đặt vị trí: góc trên bên phải (hoặc bên cạnh ShopButton)
4. Script `HUD.gd` đã có `_daily_task_btn` → nó sẽ tự link khi chạy

---

## 2. Tạo DailyTaskPanel.tscn (scene mới)

1. **File → New Scene**, chọn root node là `Control`, đặt tên `DailyTaskPanel`
2. Cấu trúc node bên trong:

```
DailyTaskPanel (Control)
├── BackButton (Button)              ← text="← Quay lại", anchor top-left
├── TitleLabel (Label)               ← text="Nhiệm vụ hằng ngày"
├── ScrollContainer                  ← anchor: Full Rect, có margin top/bottom
│   └── VBoxContainer
│       └── [TaskCard instances added dynamically by script]
├── ClaimAllButton (Button)          ← text="Nhận tất cả thưởng"
└── LoadingSpinner (Control)         ← hide() mặc định, show khi fetch từ BE
    └── Label (text="Đang tải...")
```

3. Gán script: chọn node `DailyTaskPanel` → **Attach Script** → chọn `res://scenes/daily_task/DailyTaskPanel.gd`
4. **Lưu** scene tại `res://scenes/daily_task/DailyTaskPanel.tscn`

---

## 3. Tạo TaskCard.tscn (scene mới)

1. **File → New Scene**, root node là `PanelContainer`, đặt tên `TaskCard`
2. Cấu trúc:

```
TaskCard (PanelContainer)
├── VBoxContainer
│   ├── HBoxContainer (Header)
│   │   ├── TaskIcon (TextureRect)       ← stretch_mode = Keep Aspect Centered
│   │   ├── TaskInfoVBox (VBoxContainer)
│   │   │   ├── TaskNameLabel (Label)    ← task title
│   │   │   └── TaskDescLabel (Label)    ← task description (smaller font)
│   │   └── ProgressLabel (Label)        ← text="0/3", align right
│   ├── ProgressBar (ProgressBar)        ← min=0, step=1
│   └── RewardHBox (HBoxContainer)
│       ├── RewardIcon (TextureRect)     ← icon of reward type
│       ├── RewardLabel (Label)          ← reward amount (e.g., "+100 XP")
│       └── ClaimButton (Button)         ← text="Nhận thưởng" (disabled until complete)
```

3. Gán script: chọn `TaskCard` → **Attach Script** → `res://scenes/daily_task/TaskCard.gd`
4. **Lưu** tại `res://scenes/daily_task/TaskCard.tscn`

---

## 4. Thêm DailyTaskPanel vào MainScene hoặc create Scene transition

Tuỳ vào thiết kế, bạn có thể:

**Option A:** Thêm instance vào `MainScene.tscn` (ẩn by default)
- Kéo `res://scenes/daily_task/DailyTaskPanel.tscn` vào MainScene
- Đặt tên là `DailyTaskPanel`
- Đặt `visible = false` mặc định trong Inspector

**Option B:** Tạo DailyTaskScene.tscn (scene riêng)
- **File → New Scene**, root = Control, đặt tên `DailyTaskScene`
- Kéo instance `DailyTaskPanel` vào
- **Lưu** tại `res://scenes/daily_task/DailyTaskScene.tscn`
- Script `HUD.gd` sẽ gọi `SceneTransition.fade_to_scene("res://scenes/daily_task/DailyTaskScene.tscn")`

**Khuyến nghị:** Dùng Option B (scene riêng) để tránh UI quá phức tạp trên MainScene.

---

## 5. Wire Up Signals trong HUD.gd

Đảm bảo script `HUD.gd` có:

```gdscript
# Sau khi _daily_task_btn được link:
_daily_task_btn.pressed.connect(_on_daily_task_btn_pressed)

func _on_daily_task_btn_pressed() -> void:
	SceneTransition.fade_to_scene("res://scenes/daily_task/DailyTaskScene.tscn")
	# hoặc nếu dùng Option A:
	# get_tree().root.get_node("MainScene/DailyTaskPanel").show()
```

---

## 6. TaskManager Autoload Integration

**TaskManager** đã được đăng ký trong `project.godot`:
- Tên: `TaskManager`
- Path: `res://autoloads/TaskManager.gd`
- Tải SAU `FocusManager` (load order đã set up)

Nó tự động:
- Fetch danh sách task từ BE khi game start
- Track tiến độ của từng task (qua signal từ `GardenManager` khi `care_completed`)
- Quản lý claim rewards

**Không cần thêm code** — TaskManager chạy tự động.

---

## 7. Backend Integration Points

DailyTaskService.gd đã có 2 method chính:

```gdscript
func get_tasks_async() -> Array[DailyTask]
	# GET /api/daily-tasks
	# Returns list of active tasks for today
	
func claim_task_reward_async(task_id: String) -> TaskProgress
	# POST /api/daily-tasks/{id}/claim
	# Claims reward for completed task
```

Không cần code thêm — cứ dùng service này.

---

## 8. Smoke Test Checklist

Sau khi setup xong, chạy game và kiểm tra:

- [ ] **Daily Task button**: hiển thị trên HUD, nhấn được
- [ ] **Daily Task panel**: mở đúng scene/panel, UI hiển thị
- [ ] **Task list**: load từ BE, danh sách không rỗng (minimum 3 tasks)
- [ ] **Progress tracking**: tưới hoa 3 lần → task "Tưới 3 lần" progress bar cập nhật 3/3
- [ ] **Claim button**: enabled khi task complete, disabled khi chưa
- [ ] **Claim reward**: nhấn "Nhận thưởng" → optimistic update (UI update ngay) → async sync
- [ ] **Claim All**: nhấn "Nhận tất cả thưởng" → nhận thưởng tất cả completed task
- [ ] **Daily reset**: qua nửa đêm (hoặc SET thời gian test) → danh sách task reset
- [ ] **No double claim**: nhấn Nhận thưởng 2 lần nhanh → chỉ tính 1 lần (pending_sync protection)
- [ ] **Network failure**: tắt mạng → claim thất bại → UI rollback, thưởng không nhận

---

## 9. Lỗi thường gặp

| Triệu chứng | Nguyên nhân | Cách fix |
|---|---|---|
| `_daily_task_btn` = null | Chưa thêm Button `DailyTaskButton` vào HUD.tscn | Thêm Button, đặt tên đúng |
| Task panel không mở | HUD.gd không có method `_on_daily_task_btn_pressed()` | Thêm method signal handler |
| Task list rỗng | BE chưa tạo task hoặc `IsActive=false` | POST task qua Swagger, set `IsActive=true` |
| Progress không cập nhật | GardenManager.care_completed không emit | Kiểm tra `care_completed.emit()` sau care action |
| Claim button luôn disabled | Task progress không đạt max_progress | Kiểm tra max_progress == current_progress |
| Reward không nhận sau claim | BE endpoint trả lỗi (VD: task đã claim trước) | Check error log, xem response từ BE |
| TaskManager chưa load | TaskManager load trước FocusManager | Kiểm tra order trong project.godot autoload section |

---

## 10. Data Persistence

- Task data được lưu trên BE → Godot cache locally
- `TaskProgress` (xem `domain/TaskProgress.gd`) track:
  - `task_id`: ID của task
  - `current_progress`: bao nhiêu đã làm (e.g., 3/3 watering)
  - `is_completed`: task hoàn thành chưa
  - `is_claimed`: đã nhận thưởng chưa
- Khi app restart → fetch danh sách task mới từ BE (nếu qua nửa đêm, reset)

