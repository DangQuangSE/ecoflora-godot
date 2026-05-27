# Phase 02 — Autoloads: ZoneManager + GardenManager zone plots

**Layer:** autoloads/, services/
**Testing:** skipped (--no-test)
**Spec stories covered:** FR-02, FR-03, FR-05, FR-09

---

## Goal

1. Extend `MockGardenService` to return 16 plots (8 initial + 8 zone plots).
2. Extend `GardenManager` with zone plot positions.
3. Create `ZoneManager` singleton.
4. Register `ZoneManager` in `project.godot` AFTER `UserManager`.

> **Removed:** InteractionManager guard. Input blocking is handled entirely by `CloudOverlay.ColorRect.mouse_filter = STOP` in Phase 3. No code change to InteractionManager is required.

---

## Files

| File | Layer | Action |
|------|-------|--------|
| `services/MockGardenService.gd` | services | EDIT (add 8 zone plots) |
| `autoloads/GardenManager.gd` | autoloads | EDIT (add PLOT_POSITIONS for plots 8–15) |
| `autoloads/ZoneManager.gd` | autoloads | CREATE |
| `project.godot` | config | EDIT (register ZoneManager after UserManager) |

---

## Steps

### 1. Edit `services/MockGardenService.gd`

Read the current `get_initial_plots()` implementation. It returns plots for indices 0–7. Append 8 more plots for zone plots — IDs `"plot_8"` through `"plot_15"`, all starting in `EMPTY` state with `is_zone_locked = false` (zone locked state is tracked by `ZoneManager`, not the domain Plot — **do not add `is_zone_locked` to `domain/Plot.gd`**).

```gdscript
# append after existing 8 plots in get_initial_plots():
for i in range(8, 16):
    var p := Plot.new()
    p.plot_id = "plot_%d" % i
    # all other fields default (empty, no plant)
    plots.append(p)
```

### 2. Edit `autoloads/GardenManager.gd`

Read the current `PLOT_POSITIONS` constant (or equivalent). It defines 8 Vector2 positions. Append 8 more positions for zone plots.

Zone 1 layout (2×2 grid, 120px spacing, top-left at Vector2(360, 80)):
```
plot_8:  Vector2(360, 80)
plot_9:  Vector2(480, 80)
plot_10: Vector2(360, 200)
plot_11: Vector2(480, 200)
```

Zone 2 layout (2×2 grid, top-left at Vector2(360, 320)):
```
plot_12: Vector2(360, 320)
plot_13: Vector2(480, 320)
plot_14: Vector2(360, 440)
plot_15: Vector2(480, 440)
```

**Note:** These positions are placeholders — user will adjust in Godot Editor after TileMap layout is confirmed.

### 3. Create `autoloads/ZoneManager.gd`

```gdscript
extends Node

signal zone_notification(zone_id: String)
signal zone_unlocked(zone_id: String)

enum ZoneState { LOCKED, NOTIFIED, UNLOCKED }

var _zones: Array[ZoneDefinition] = []
var _states: Dictionary = {}  # zone_id -> ZoneState

func _ready() -> void:
	_zones = [
		ZoneDefinition.create("zone_1", 3,
			["plot_8", "plot_9", "plot_10", "plot_11"],
			Vector2(360.0, 80.0)),
		ZoneDefinition.create("zone_2", 6,
			["plot_12", "plot_13", "plot_14", "plot_15"],
			Vector2(360.0, 320.0)),
	]
	for z: ZoneDefinition in _zones:
		_states[z.zone_id] = ZoneState.LOCKED
	UserManager.level_up.connect(_on_level_up)

func _on_level_up(new_level: int) -> void:
	for z: ZoneDefinition in _zones:
		if _states[z.zone_id] == ZoneState.LOCKED and new_level >= z.required_level:
			_states[z.zone_id] = ZoneState.NOTIFIED
			zone_notification.emit(z.zone_id)

func request_unlock(zone_id: String) -> void:
	if _states.get(zone_id, ZoneState.LOCKED) != ZoneState.NOTIFIED:
		return
	_states[zone_id] = ZoneState.UNLOCKED
	zone_unlocked.emit(zone_id)

func is_plot_locked(plot_id: String) -> bool:
	for z: ZoneDefinition in _zones:
		if plot_id in z.plot_ids:
			return _states[z.zone_id] != ZoneState.UNLOCKED
	return false

func get_zone_state(zone_id: String) -> ZoneState:
	return _states.get(zone_id, ZoneState.LOCKED)

func get_all_zones() -> Array[ZoneDefinition]:
	return _zones
```

**Key design decisions:**
- `is_plot_locked(plot_id: String)` — matches the `"plot_N"` string scheme used throughout the codebase
- `get_all_zones()` — public accessor used by `GardenScene._spawn_zone_overlays()` (no direct `_zones` access from scenes)
- `get_zone_state(zone_id)` — public accessor used by `CloudOverlay` catch-up in `_ready()`
- Zone state in ZoneManager only — `domain/Plot.gd` is NOT modified

### 4. Edit `project.godot`

Add in `[autoload]` section, **after** `UserManager` line:

```
ZoneManager="*res://autoloads/ZoneManager.gd"
```

**Order is load-order:** ZoneManager connects `UserManager.level_up` in `_ready()` — it must appear after `UserManager` in project.godot.

---

## Success Criteria

- [ ] `MockGardenService.get_initial_plots()` returns 16 plots (IDs `"plot_0"` through `"plot_15"`)
- [ ] `GardenManager` has PLOT_POSITIONS for all 16 plots
- [ ] `ZoneManager` autoload registers and loads without errors
- [ ] `ZoneManager._states` initializes LOCKED for both zones
- [ ] `UserManager.level_up` signal connected in `_ready()`
- [ ] `is_plot_locked("plot_8")` returns `true` before zone_1 unlocked
- [ ] `is_plot_locked("plot_0")` returns `false` (initial plots never locked)
- [ ] `request_unlock("zone_1")` when NOTIFIED → emits `zone_unlocked`, state=UNLOCKED
- [ ] `request_unlock("zone_1")` when LOCKED → no-op
- [ ] `domain/Plot.gd` is NOT modified

---

## Risks

- **HIGH**: If ZoneManager loads before UserManager, `UserManager.level_up.connect()` will fail. Verify project.godot autoload order.
- **MEDIUM**: Zone plot positions (360,80) and (360,320) are placeholders — TileMap must have space. User adjusts in Editor after confirming map layout.
