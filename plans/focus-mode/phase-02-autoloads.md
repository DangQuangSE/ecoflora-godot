# Phase 2: Autoloads — FocusManager + GardenManager edit + project.godot

testing: skipped (--no-test)

## Layer

`autoloads/` — Node singletons, imports domain only (FocusSession). `scenes/` layer is never imported here.

## Files

| File | Layer | Action |
|---|---|---|
| `autoloads/FocusManager.gd` | autoloads | CREATE |
| `autoloads/GardenManager.gd` | autoloads | EDIT — add `apply_focus_xp_bulk()` + connect FocusManager signals in `_ready()` |
| `project.godot` | config | EDIT — register FocusManager autoload after ZoneManager |

---

## Requirements

Deliver a working `FocusManager` singleton that runs the IDLE → SETUP → ACTIVE → COMPLETED / FAILED state machine, detects app-background events, and emits signals when a session ends. `GardenManager` must respond to those signals by applying bulk XP to all occupied plots in a single synchronous frame.

---

## Story Coverage

| Story | Priority | Satisfied by |
|---|---|---|
| Enter classroom, set timer, press Start | P1 | `FocusManager.start_session(duration_sec)` |
| App background detection → violation count | P1 | `_notification(NOTIFICATION_APPLICATION_PAUSED)` in FocusManager |
| Complete session → +XP all planted flowers | P1 | `GardenManager._on_session_completed()` → `apply_focus_xp_bulk(+xp)` |
| Fail session → -20 XP all planted flowers | P1 | `GardenManager._on_session_failed()` → `apply_focus_xp_bulk(-20)` |
| Countdown overlay data source | P2 | `FocusManager.tick` signal carries remaining seconds |

---

## Steps

1. Create `autoloads/FocusManager.gd` extending `Node`. Define signals at the top: `session_completed(minutes_focused: int)`, `session_failed()`, `session_cancelled()`, `tick(remaining_seconds: int)`, `violation_updated(count: int)`. Define `enum State { IDLE, ACTIVE, COMPLETED, FAILED }` — **no SETUP state** (ClassroomScene handles setup UI while FocusManager stays IDLE). Add `@export var bypass_violation_detection: bool = false` for editor/desktop testing. Add a private `_session: FocusSession` variable (initially null). Add `_set_state(new_state: State) -> void` that stores the new state, calls `set_process(new_state == State.ACTIVE)`, and uses `push_warning()` for illegal transitions.

2. Implement `start_session(duration_sec: int) -> void` — guard that state must be IDLE, instantiate a new `FocusSession` with the given duration and `max_violations = 3`, then call `_set_state(State.ACTIVE)`.

3. Implement `cancel_session() -> void` with explicit guard:
   ```gdscript
   func cancel_session() -> void:
       if _state not in [State.ACTIVE, State.IDLE]:
           return
       _set_state(State.IDLE)
       _session = null
       session_cancelled.emit()
   ```
   This guard ensures calling `cancel_session()` from COMPLETED or FAILED state (e.g., from `ClassroomScene.tree_exiting`) is a no-op.

4. Implement `_process(delta: float) -> void`. **Mandate this exact order to prevent re-entrant race:**
   ```gdscript
   func _process(delta: float) -> void:
       _session.elapsed_seconds += delta
       tick.emit(_session.get_remaining_seconds())
       if _session.is_completed():
           var minutes := _session.get_minutes_focused()
           _set_state(State.COMPLETED)   # set_process(false) — no more _process after this line
           session_completed.emit(minutes)
   ```
   Note: `elapsed_seconds` counts **foreground time only** — `_process` does not run while the app is backgrounded on Android. This is intentional for MVP; wall-clock timer requires Android plugin (deferred).

5. Implement `_notification(what: int) -> void`. Check `bypass_violation_detection` first:
   ```gdscript
   func _notification(what: int) -> void:
       if bypass_violation_detection:
           return
       if what == NOTIFICATION_APPLICATION_PAUSED and _state == State.ACTIVE:
           _session.violation_count += 1
           violation_updated.emit(_session.violation_count)
           if _session.is_failed():
               _set_state(State.FAILED)
               session_failed.emit()
   ```
   Set `bypass_violation_detection = true` in the Godot Editor Inspector on FocusManager node during development to prevent Alt-Tab from triggering false violations.

6. Add `apply_focus_xp_bulk(xp_delta: int) -> void` to `GardenManager.gd`:
   ```gdscript
   func apply_focus_xp_bulk(xp_delta: int) -> void:
       for plot: Plot in _plots:
           if not plot.is_occupied or plot.is_pending_sync:
               push_warning("GardenManager.apply_focus_xp_bulk: skipping plot %s (pending_sync=%s)" % [plot.id, plot.is_pending_sync])
               continue
           var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
           if template == null:
               push_warning("GardenManager.apply_focus_xp_bulk: no template for plot %s" % plot.id)
               continue
           plot.current_plant.current_xp = maxi(0, plot.current_plant.current_xp + xp_delta)
           plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
       plots_updated.emit(_plots)
   ```
   No `await`, no `is_pending_sync` toggling — synchronous batch write with no mock service call.

7. **BLOCK FIX — load order:** Do NOT connect FocusManager signals in `GardenManager._ready()` — GardenManager loads before FocusManager and cannot reference it by name yet. Instead, in `FocusManager._ready()`, connect to GardenManager (which is guaranteed to exist):
   ```gdscript
   func _ready() -> void:
       GardenManager.session_completed   # wrong — GardenManager doesn't emit this
       # Correct pattern:
       session_completed.connect(GardenManager._on_focus_session_completed)
       session_failed.connect(GardenManager._on_focus_session_failed)
   ```
   Add to `GardenManager.gd`: `func _on_focus_session_completed(minutes: int) -> void` calling `apply_focus_xp_bulk(minutes)`, and `func _on_focus_session_failed() -> void` calling `apply_focus_xp_bulk(-20)`. These are plain methods (not connected in GardenManager._ready). Add FocusManager entry to `project.godot` autoloads section **after ZoneManager**: `FocusManager="*res://autoloads/FocusManager.gd"`.

---

## Success Criteria

- Calling `FocusManager.start_session(300)` from any scene sets state to ACTIVE and `_process` starts emitting `tick` signals every frame.
- Simulating `NOTIFICATION_APPLICATION_PAUSED` four times while ACTIVE emits `session_failed` and transitions state to FAILED (not ACTIVE).
- Calling `start_session(60)` and fast-forwarding `elapsed_seconds` to 60 causes `session_completed(1)` to emit.
- `apply_focus_xp_bulk(-20)` on a plot with `current_xp = 10` leaves `current_xp == 0` (not -10).
- `apply_focus_xp_bulk(5)` on two occupied plots emits exactly one `plots_updated` signal (not two).
- A plot with `is_pending_sync == true` is skipped by `apply_focus_xp_bulk` — its XP does not change.
- Static analysis passes on both `FocusManager.gd` and `GardenManager.gd` with `--check-only`.

---

## Risks

- `NOTIFICATION_APPLICATION_PAUSED` fires on desktop when the Godot editor loses focus during development. This causes false violations in-editor. Mitigation: note in code comment that this is expected; only ship to Android for real focus testing.
- GardenManager._ready() references FocusManager by name — this requires FocusManager to be registered in project.godot before GardenManager's _ready runs, OR listed after GardenManager. Because FocusManager is added after ZoneManager (which is after GardenManager), GardenManager._ready() will try to reference FocusManager before it exists. Mitigation: move the FocusManager signal connection to a deferred call (`call_deferred`) or place the connection in FocusManager._ready() instead — FocusManager connecting to its own signals on GardenManager is architecturally equivalent and avoids the load-order issue.
