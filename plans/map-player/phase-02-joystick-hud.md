# Phase 2: Dynamic Joystick + HUD

## Layer
Presentation — `scenes/hud/`

## Files

| File | Node Type | Layer |
|------|-----------|-------|
| `scenes/hud/DynamicJoystick.tscn` | Control (root, full-screen) | Presentation |
| `scenes/hud/DynamicJoystick.gd` | script | Presentation |
| `scenes/hud/HUD.tscn` | CanvasLayer (root, layer=10) | Presentation |
| `scenes/hud/HUD.gd` | script | Presentation |

## Spec Stories
US-03 (joystick appears on hold), US-04 (drag moves player), US-05 (lift hides joystick)

## Node Layout

```
HUD (CanvasLayer, layer=10)
  └── DynamicJoystick (Control, anchors=full_rect, mouse_filter=MOUSE_FILTER_IGNORE)
        └── Background (Panel, 120×120, visible=false)
              └── Knob (ColorRect placeholder 32×32, anchor=center)
```

**CanvasLayer.layer = 10**: trên world (0), dưới SceneTransition fade (128).

## Steps

1. Tạo `scenes/hud/DynamicJoystick.tscn` với layout trên. Root Control: anchors full rect, **`mouse_filter = MOUSE_FILTER_IGNORE`** (bắt buộc — nếu để mặc định STOP sẽ ăn hết touch events của garden).

2. Tạo `DynamicJoystick.gd`. Dùng **`_unhandled_input()`** thay vì `_input()` — joystick chỉ consume events chưa được xử lý; SwipeInteractionHandler sẽ dùng `_input()` với ưu tiên cao hơn. Khi consume event, gọi `get_viewport().set_input_as_handled()`.

3. Touch-up detection: `InputEventScreenTouch` với `pressed == false` — **KHÔNG** đọc `.pressed` trên `InputEventScreenDrag` (field không tồn tại, compile nhưng sai giá trị).

4. Joystick zone: chỉ nhận touch ở `y > viewport_height * 0.6` (bottom 40%). Check trong `_unhandled_input()` khi `event is InputEventScreenTouch and event.pressed`.

5. Hold timer: `_process(delta)` tăng `_hold_timer` khi có `_touch_index >= 0` và chưa active. Sau `HOLD_DURATION` (1.0s) → `_show_joystick()`.

6. Tạo `HUD.tscn` (CanvasLayer root, **layer=10**). Tạo `HUD.gd` kết nối signal `direction_changed` từ joystick, re-emit như `joystick_direction_changed`.

## Exact Code

### DynamicJoystick.gd

```gdscript
class_name DynamicJoystick
extends Control

signal direction_changed(direction: Vector2)

const HOLD_DURATION := 1.0
const MAX_RADIUS    := 60.0
const ZONE_Y_RATIO  := 0.6  # bottom 40% of screen

@onready var _background: Control = $Background
@onready var _knob: Control       = $Background/Knob

var _touch_index: int    = -1
var _hold_timer: float   = 0.0
var _origin: Vector2     = Vector2.ZERO
var _active: bool        = false

func _ready() -> void:
    _background.visible = false
    mouse_filter = MOUSE_FILTER_IGNORE  # CRITICAL: không ăn events ngoài joystick zone

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        if event.index == _touch_index and _active:
            _handle_drag(event)
            get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
    if _touch_index >= 0 and not _active:
        _hold_timer += delta
        if _hold_timer >= HOLD_DURATION:
            _show_joystick()

func _handle_touch(event: InputEventScreenTouch) -> void:
    if event.pressed:
        var zone_y: float = get_viewport().get_visible_rect().size.y * ZONE_Y_RATIO
        if event.position.y < zone_y:
            return
        _touch_index = event.index
        _origin      = event.position
        _hold_timer  = 0.0
        get_viewport().set_input_as_handled()
    elif event.index == _touch_index:
        _reset()

func _show_joystick() -> void:
    _active = true
    _background.global_position = _origin - _background.size / 2.0
    _background.visible = true

func _handle_drag(event: InputEventScreenDrag) -> void:
    var offset: Vector2  = event.position - _origin
    var clamped: Vector2 = offset.limit_length(MAX_RADIUS)
    _knob.position = clamped
    direction_changed.emit(clamped / MAX_RADIUS)

func _reset() -> void:
    _touch_index = -1
    _hold_timer  = 0.0
    _active      = false
    _background.visible = false
    _knob.position      = Vector2.ZERO
    direction_changed.emit(Vector2.ZERO)
```

### HUD.gd

```gdscript
class_name HUD
extends CanvasLayer

signal joystick_direction_changed(direction: Vector2)

@onready var _joystick: DynamicJoystick = $DynamicJoystick

func _ready() -> void:
    _joystick.direction_changed.connect(_on_joystick_direction)

func _on_joystick_direction(dir: Vector2) -> void:
    joystick_direction_changed.emit(dir)
```

## Done When

- [ ] Touch ở top 60% → KHÔNG start timer (touch_index stays -1)
- [ ] Hold < 1.0s ở bottom 40% → joystick KHÔNG hiện
- [ ] Hold ≥ 1.0s ở bottom 40% → Background hiện tại vị trí touch
- [ ] Drag → Knob di chuyển, `direction_changed` emit Vector2 trong [-1, 1]
- [ ] Nhấc tay → Background ẩn, Knob về center, emit Vector2.ZERO
- [ ] Garden touch events KHÔNG bị chặn khi HUD active (verify bằng debug Area2D)
- [ ] `CanvasLayer.layer = 10` được set trong HUD.tscn Inspector
- [ ] Không có `print()` trong DynamicJoystick.gd hay HUD.gd
