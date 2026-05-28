# Phase 03 — Scenes: CloudOverlay + UnlockBanner + GardenScene integration

**Layer:** scenes/
**Testing:** skipped (--no-test)
**Spec stories covered:** FR-06, FR-07, FR-08, P1 user stories, P2 pulse

---

## Goal

1. `CloudOverlay.gd / .tscn` — Node2D covering a zone's 4 plots; tappable after notified; fades out on unlock.
2. `UnlockBanner.gd / .tscn` — CanvasLayer layer=11 center-screen notification.
3. `GardenScene.gd` — spawn PlotNodes for zone plots + one CloudOverlay per zone.

---

## Files

| File | Layer | Action |
|------|-------|--------|
| `scenes/garden/CloudOverlay.gd` | scenes | CREATE |
| `scenes/garden/CloudOverlay.tscn` | scenes | CREATE |
| `scenes/garden/UnlockBanner.gd` | scenes | CREATE |
| `scenes/garden/UnlockBanner.tscn` | scenes | CREATE |
| `scenes/garden/GardenScene.gd` | scenes | EDIT |

---

## Steps

### 1. Create `scenes/garden/CloudOverlay.gd`

```gdscript
class_name CloudOverlay
extends Node2D

@export var zone_texture: Texture2D  # assigned later when art is ready

@onready var _rect: ColorRect = $ColorRect

var _zone_id: String = ""
var _tappable: bool = false
var _pulse_tween: Tween = null

func setup(zone_id: String) -> void:
	_zone_id = zone_id

func _ready() -> void:
	ZoneManager.zone_notification.connect(_on_notified)
	ZoneManager.zone_unlocked.connect(_on_unlocked)
	# Catch-up: if ZoneManager already notified this zone before we loaded
	var state := ZoneManager.get_zone_state(_zone_id)
	if state == ZoneManager.ZoneState.NOTIFIED:
		_on_notified(_zone_id)
	elif state == ZoneManager.ZoneState.UNLOCKED:
		queue_free()

func _on_notified(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = true
	_start_pulse()

func _start_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_rect, "modulate:a", 0.55, 0.5)
	_pulse_tween.tween_property(_rect, "modulate:a", 1.0, 0.5)

func _on_unlocked(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = false
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	if ZoneManager.zone_notification.is_connected(_on_notified):
		ZoneManager.zone_notification.disconnect(_on_notified)
	if ZoneManager.zone_unlocked.is_connected(_on_unlocked):
		ZoneManager.zone_unlocked.disconnect(_on_unlocked)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

func _on_rect_gui_input(event: InputEvent) -> void:
	if not _tappable:
		return
	var pressed: bool = false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		get_viewport().set_input_as_handled()
		ZoneManager.request_unlock(_zone_id)
```

**Notes:**
- Uses `_rect.gui_input` signal (wired in .tscn or `_ready()`) — not `_input()`. This is the same pattern as `PlotNode._ready()` and avoids coordinate-space mismatch.
- `setup(zone_id)` MUST be called before `add_child()` — see GardenScene step.
- Catch-up block in `_ready()` handles the case where player was already at Lv3+ when GardenScene loads.
- `is_connected()` guards prevent crash if `_on_unlocked` fires twice.

### 2. Create `scenes/garden/CloudOverlay.tscn`

Scene tree:
```
CloudOverlay (Node2D) [script=CloudOverlay.gd, z_index=5]
└── ColorRect [size=240×240, color=Color(0.75, 0.85, 0.95, 0.92), mouse_filter=STOP]
```

No AnimationPlayer needed — pulse is handled by `_start_pulse()` Tween in code.

**`mouse_filter = STOP` on ColorRect is mandatory** — this is what prevents all taps from reaching PlotNode below.

Wire `ColorRect.gui_input` → `CloudOverlay._on_rect_gui_input` in the scene's node connections (or in `_ready()`: `_rect.gui_input.connect(_on_rect_gui_input)`).

ColorRect size 240×240 covers a 2×2 grid at 120px spacing. Adjust if plot spacing differs.

### 3. Create `scenes/garden/UnlockBanner.gd`

```gdscript
class_name UnlockBanner
extends CanvasLayer

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label
@onready var _close_btn: Button = $Panel/CloseButton

func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(_on_close_pressed)

func show_for_zone(_zone_id: String) -> void:
	_label.text = "Khu vườn mới đã mở khóa!\nTap đám mây để xua tan."
	visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)

func _on_close_pressed() -> void:
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	await tween.finished
	if is_instance_valid(self):
		queue_free()
```

### 4. Create `scenes/garden/UnlockBanner.tscn`

Scene tree:
```
UnlockBanner (CanvasLayer) [layer=11, script=UnlockBanner.gd]
└── Panel [anchor: 0.1/0.35/0.9/0.65 — centered 360×160]
    ├── Label [text="", horizontal_alignment=CENTER, autowrap_mode=Word]
    └── CloseButton (Button) [text="Đóng", anchored bottom-center]
```

CanvasLayer layer=11 — above HUD (10), UserProfileCard (9), FlowerInfoCard (8).

### 5. Edit `scenes/garden/GardenScene.gd`

**5a. Add preloads at top:**
```gdscript
const CloudOverlayScene := preload("res://scenes/garden/CloudOverlay.tscn")
const UnlockBannerScene := preload("res://scenes/garden/UnlockBanner.tscn")
```

**5b. Add member variable:**
```gdscript
var _active_banner: CanvasLayer = null
```

**5c. In `_ready()`, after `_spawn_plots()` call:**
```gdscript
_spawn_zone_overlays()
ZoneManager.zone_notification.connect(_on_zone_notification)
```

**5d. `_spawn_plots()` is already dynamic** (iterates from GardenManager). Once `MockGardenService.get_initial_plots()` returns 16 plots in Phase 2, `_spawn_plots()` will automatically create PlotNode instances for all 16 plots including zone plots. No change needed here — just ensure `_spawn_plots()` runs before `_spawn_zone_overlays()` in `_ready()`.

**`_on_plots_updated` contract:** The existing `mini(plots.size(), _plot_nodes.size())` guard handles any size mismatch safely. After Phase 2, both arrays have 16 entries.

**5e. Add methods:**
```gdscript
func _spawn_zone_overlays() -> void:
	for zone: ZoneDefinition in ZoneManager.get_all_zones():
		var overlay: Node2D = CloudOverlayScene.instantiate()
		overlay.call("setup", zone.zone_id)   # BEFORE add_child — critical
		overlay.position = zone.world_position
		add_child(overlay)

func _on_zone_notification(zone_id: String) -> void:
	# Cap to one active banner — do not stack
	if _active_banner != null and is_instance_valid(_active_banner):
		return
	_active_banner = UnlockBannerScene.instantiate()
	get_tree().root.add_child(_active_banner)
	_active_banner.call("show_for_zone", zone_id)

func _exit_tree() -> void:
	if ZoneManager.zone_notification.is_connected(_on_zone_notification):
		ZoneManager.zone_notification.disconnect(_on_zone_notification)
	if _active_banner != null and is_instance_valid(_active_banner):
		_active_banner.queue_free()
		_active_banner = null
```

---

## Success Criteria

- [ ] Game starts → 2 blue/grey cloud overlays visible at zone positions, covers plots beneath
- [ ] Tapping plots under cloud → no plot interaction (mouse_filter=STOP blocks)
- [ ] Leveling to Lv3 → `UnlockBanner` appears center screen with correct Vietnamese text
- [ ] Tapping "Đóng" button → banner fades and disappears
- [ ] CloudOverlay for zone_1 begins pulse animation after banner
- [ ] Tapping cloud → fade out 0.6s → overlay queue_free'd → 4 zone_1 plots interactable
- [ ] Zone_2 cloud remains locked until Lv6
- [ ] Initial 8 plots unaffected
- [ ] Loading GardenScene when already at Lv3 → zone_1 cloud already in pulse state (catch-up)
- [ ] No orphaned banner nodes when leaving/re-entering GardenScene

---

## Risks

- **CRITICAL**: `CloudOverlay.setup(zone_id)` must be called before `add_child()` — done in `_spawn_zone_overlays()` above.
- **MEDIUM**: Zone plot positions (360,80) and (360,320) are placeholder — user adjusts in Godot Editor.
- **LOW**: `_active_banner` only caps one banner at a time. If both zones notify in the same frame (extreme XP jump), zone_2 notification is silently dropped. Acceptable for MVP — document in plan Risks.
