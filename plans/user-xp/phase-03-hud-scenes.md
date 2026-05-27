# Phase 3: HUD Scenes — UserHUD + UserProfileCard

## Layer
`scenes/` — Nodes/Controls. Import autoloads và domain.

## Files

| File | Layer |
|------|-------|
| `scenes/hud/UserHUD.tscn` | scenes |
| `scenes/hud/UserHUD.gd` | scenes |
| `scenes/hud/UserProfileCard.tscn` | scenes |
| `scenes/hud/UserProfileCard.gd` | scenes |
| `scenes/hud/HUD.tscn` | scenes — thêm UserHUD instance |

## Steps

### A. UserHUD.tscn
Node tree:
```
UserHUD (Control, anchor top-left)
  AvatarRect (ColorRect, 48×48, circle shape nếu có StyleBoxFlat)
  LevelLabel (Label, "Lv.1")
  XPBar (ProgressBar, 120×10, show_percentage=false)
```
- Root Control: `mouse_filter = MOUSE_FILTER_STOP`, size ~150×60, anchored top-left (offset_left=8, offset_top=8)
- XPBar và AvatarRect: `mouse_filter = MOUSE_FILTER_PASS` (tránh nuốt input của joystick/bag)

### B. UserHUD.gd
```gdscript
@onready var _avatar: ColorRect    = $AvatarRect
@onready var _level_label: Label   = $LevelLabel
@onready var _xp_bar: ProgressBar  = $XPBar

var _is_animating_level_up: bool = false  # guard tránh Tween bị ghi đè

func _ready() -> void:
    UserManager.xp_gained.connect(_on_xp_gained)
    UserManager.level_up.connect(_on_level_up)
    _refresh()

func _refresh() -> void:
    var p := UserManager.get_profile()
    _level_label.text = "Lv.%d" % p.level
    _xp_bar.max_value = p.xp_to_next_level()
    _xp_bar.value = p.current_xp
```

- `_on_xp_gained(amount)`: gọi `_refresh()` (float label XP bỏ qua — out of scope sprint này)
- `_on_level_up(new_level)`: gọi `_refresh()`, nếu `not _is_animating_level_up` thì trigger animation
- Kết nối `gui_input` để mở UserProfileCard khi tap

**Level-up flash animation** (dùng `_is_animating_level_up` guard):
```gdscript
func _play_level_up_anim(new_level: int) -> void:
    _is_animating_level_up = true
    var tween := create_tween()
    tween.tween_property(_avatar, "modulate", Color.WHITE, 0.1)
    tween.tween_property(_avatar, "modulate", Color(0.6, 0.4, 0.2, 1), 0.3)
    await tween.finished
    _is_animating_level_up = false
    _spawn_levelup_label(new_level)
```

**Level-up float label** (Control-based, KHÔNG dùng FloatLabel.gd vì đó là world-space Node2D):
```gdscript
func _spawn_levelup_label(new_level: int) -> void:
    var lbl := Label.new()
    lbl.text = "Level Up! Lv.%d" % new_level
    lbl.position = Vector2(0, -10)
    lbl.modulate = Color(0.4, 0.9, 0.3, 1)
    add_child(lbl)
    var tw := create_tween().set_parallel(true)
    tw.tween_property(lbl, "position:y", lbl.position.y - 50.0, 1.0)
    tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.3)
    await tw.finished
    lbl.queue_free()
```

### C. UserProfileCard.tscn
Mirror cấu trúc FlowerInfoCard.tscn, layer=9:
```
UserProfileCard (CanvasLayer, layer=9, visible=false)
  Dimmer (ColorRect, anchor full-screen, color=(0,0,0,0.25), mouse_filter=STOP)
  Card (Panel, anchor_left=0 anchor_top=1 anchor_right=1 anchor_bottom=1, offset_top=-320)
    CloseBtn (Button "✕", top-right)
    Content (VBoxContainer)
      LevelLabel (Label, "Level: 1", font_size=20)
      TotalXPLabel (Label, "Tổng XP: 0", font_size=14)
      HarvestLabel (Label, "Lần thu hoạch: 0", font_size=14)
```

### D. UserProfileCard.gd
- `open()`: visible=true, populate labels từ `UserManager.get_profile()`, tween Card từ `offset_top=0` → `offset_top=-320` trong 0.22s TRANS_QUAD EASE_OUT
- `close()`: tween ngược lại 0.15s, sau đó `visible=false`
- Dimmer `gui_input` → `close()` khi press
- **Mutual exclusion**: không cần — cả 2 card có thể mở cùng lúc (layer khác nhau: FlowerInfoCard=8, UserProfileCard=9)

### E. Embed trong HUD.tscn
- Thêm `UserHUD.tscn` làm instanced child của HUD (CanvasLayer)
- Anchor top-left, offset_left=8, offset_top=8
- Kiểm tra không chồng lên bag button (bên phải) hay joystick (bottom-left)
- UserProfileCard được spawn bởi UserHUD khi tap, add_child vào CanvasLayer root hoặc GardenScene

## Success Criteria

- Avatar + level + XP bar hiển thị top-left khi chạy GardenScene
- Harvest hoa → XP bar cập nhật ngay, level label đúng
- Level up → flash animation trên avatar, float label "Level Up! Lv.X" xuất hiện
- Tap avatar → UserProfileCard slide lên từ dưới (0.22s), hiện đúng level/total_xp/harvest_count
- Tap dimmer → card đóng lại
- Joystick và bag button vẫn hoạt động bình thường (không bị nuốt input)

## Spec Stories

- P1: UserHUD widget top-left (avatar, level label, XP bar)
- P1: Level-up animation (flash + float label)
- P2: Tap avatar → UserProfileCard
- P2: Float "+X XP" near avatar — bỏ qua sprint này

## Testing
Skipped (--no-test).
