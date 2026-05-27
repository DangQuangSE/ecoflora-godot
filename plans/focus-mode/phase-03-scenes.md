# Phase 3: Scenes — SchoolScene + ClassroomScene + FocusTimerUI

testing: skipped (--no-test)

## Layer

`scenes/` — Node/Control trees, reads from autoloads (FocusManager, SceneTransition) and domain (FocusSession indirectly). Never imported by autoloads.

## Files

| File | Layer | Action |
|---|---|---|
| `scenes/school/SchoolScene.tscn` | scenes | CREATE — Node2D root |
| `scenes/school/SchoolScene.gd` | scenes | CREATE — player input + portal setup |
| `scenes/school/ClassroomScene.tscn` | scenes | CREATE — Node2D root |
| `scenes/school/ClassroomScene.gd` | scenes | CREATE — Area2D trigger + launch FocusTimerUI |
| `scenes/school/FocusTimerUI.tscn` | scenes | CREATE — CanvasLayer root |
| `scenes/school/FocusTimerUI.gd` | scenes | CREATE — countdown display + cancel button |
| `scenes/garden/GardenScene.tscn` | scenes | EDIT — add Portal node pointing to SchoolScene |

---

## Requirements

Deliver a playable school environment where the player travels from the garden to a campus scene, enters a classroom, configures and starts a focus session via a full-screen overlay, and receives live countdown feedback with violation count. The overlay tears down cleanly whether the session ends normally, fails, or is cancelled.

---

## Story Coverage

| Story | Priority | Satisfied by |
|---|---|---|
| Walk from garden to school via portal | P1 | GardenScene Portal + SchoolScene |
| Enter classroom, set timer, press Start | P1 | ClassroomScene Area2D + FocusTimerUI setup panel |
| App background → violation count shown | P1 | FocusTimerUI._on_violation_updated() |
| Complete session → reward feedback | P1 | FocusTimerUI._on_session_completed() banner |
| Fail session → penalty feedback | P1 | FocusTimerUI._on_session_failed() banner |
| Countdown overlay (MM:SS + violations + Cancel) | P2 | FocusTimerUI countdown label |
| FPT-style campus background, player moves | P2 | SchoolScene background sprite + Player node |

---

## Steps

1. Build `SchoolScene.tscn` as a Node2D containing: a `Sprite2D` for the campus background (use placeholder ColorRect if PNG not yet available), a `Player` node instance (reuse existing Player scene), and a `Portal` (Area2D, `target_scene = "res://scenes/garden/GardenScene.tscn"`, `disabled = false`) positioned at the campus exit. Also add a second `Portal` with `target_scene = "res://scenes/school/ClassroomScene.tscn"` near the classroom entrance. Attach `SchoolScene.gd` which has no logic beyond ensuring the player starts at the correct spawn position.

2. Edit `GardenScene.tscn` to add one `Portal` node with `target_scene = "res://scenes/school/SchoolScene.tscn"` and `disabled = false`, positioned at the garden exit. No script changes needed — `Portal.gd` already handles the transition.

3. Build `ClassroomScene.tscn` as a Node2D containing: a background `Sprite2D` (classroom interior PNG or placeholder), an `Area2D` named `ClassroomTrigger` (with a `CollisionShape2D` covering the entry zone), a `Player` node, a `Portal` back to SchoolScene, and an empty `CanvasLayer` slot (FocusTimerUI will be added at runtime). Attach `ClassroomScene.gd` which connects `ClassroomTrigger.body_entered` to show the setup panel inside FocusTimerUI. On `tree_exiting`, call `FocusManager.cancel_session()` to clean up any running session if the player force-navigates away.

4. Build `FocusTimerUI.tscn` as a `CanvasLayer` (layer = 10) containing a full-screen semi-transparent background panel with **three mutually-exclusive sub-panels**:
   - **setup sub-panel** (visible when FocusTimerUI first opens — FocusManager is IDLE): HSlider (range 5–120 min, default 25, step 5) + Label showing current value + Start button.
   - **running sub-panel** (visible while ACTIVE): large `Label` for MM:SS countdown, `Label` for "Vi phạm: X / 3", Cancel button.
   - **result sub-panel** (visible after COMPLETED or FAILED): `Label` for result message ("+X XP cho tất cả cây" or "-20 XP cho tất cả cây"), "Quay lại trường" button that calls `SceneTransition.fade_to("res://scenes/school/SchoolScene.tscn")` then `queue_free()`.

5. Implement `FocusTimerUI.gd`:
   - In `_ready()`: show setup sub-panel, hide running + result sub-panels. Connect:
     - `FocusManager.tick.connect(_on_tick)` — update MM:SS label
     - `FocusManager.violation_updated.connect(_on_violation_updated)` — update violation label
     - `FocusManager.session_completed.connect(_on_session_completed, CONNECT_ONE_SHOT)`
     - `FocusManager.session_failed.connect(_on_session_failed, CONNECT_ONE_SHOT)`
     - `FocusManager.session_cancelled.connect(queue_free, CONNECT_ONE_SHOT)`
   - In `_exit_tree()`: disconnect persistent signals (tick, violation_updated) if still connected:
     ```gdscript
     func _exit_tree() -> void:
         if FocusManager.tick.is_connected(_on_tick):
             FocusManager.tick.disconnect(_on_tick)
         if FocusManager.violation_updated.is_connected(_on_violation_updated):
             FocusManager.violation_updated.disconnect(_on_violation_updated)
     ```
   - `_on_session_completed(minutes)`: hide running panel, show result panel, set result label "+%d XP cho tất cả cây" % minutes.
   - `_on_session_failed()`: hide running panel, show result panel, set result label "-20 XP cho tất cả cây".
   - Start button `pressed`: read HSlider value × 60 → `FocusManager.start_session(duration_sec)`, swap to running sub-panel.
   - Cancel button `pressed`: `FocusManager.cancel_session()` (this emits `session_cancelled` → `queue_free` via CONNECT_ONE_SHOT).

6. Wire `ClassroomScene.gd`: when `ClassroomTrigger.body_entered` fires for the Player, instantiate `FocusTimerUI.tscn` and add it as a child of the ClassroomScene (not root). FocusManager stays IDLE — the setup sub-panel is shown immediately (no state change needed). The state advances to ACTIVE only when the player presses Start. In `tree_exiting`:
   ```gdscript
   func _notification(what: int) -> void:
       if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
           FocusManager.cancel_session()  # guard inside cancel_session handles COMPLETED/FAILED state safely
   ```
   **Note:** Player state (position, animation) resets on every scene transition — this is accepted for MVP.

7. Format the `_on_tick` handler to display `MM:SS`: compute minutes and seconds from `remaining_seconds` using integer division and modulo, then set the countdown label text. Ensure the label updates every frame while ACTIVE (driven by FocusManager.tick signal, which fires every _process call).

---

## Success Criteria

- Player standing on the GardenScene portal causes a fade transition to SchoolScene within 1 second (verified by playtesting).
- Player walking into the classroom Area2D trigger causes FocusTimerUI setup panel to appear with duration selector and Start button visible.
- Setting duration to 5 minutes and pressing Start shows the running panel with countdown starting at "05:00" and decreasing.
- Minimizing the app increments the violation counter label in FocusTimerUI on resume.
- After 4 violations, the fail panel appears with "-20 XP" message; garden plots reflect reduced XP when the player returns.
- Pressing Cancel while timer is running hides FocusTimerUI and returns control to the classroom scene with no crash.
- Navigating away from ClassroomScene via the Portal (not Cancel) does not leave FocusManager in ACTIVE state — verified by re-entering the classroom and confirming no ghost session running.

---

## Risks

- FocusTimerUI added as child of ClassroomScene gets freed when ClassroomScene exits — this is the desired behavior (signal chain collapses gracefully because FocusManager.cancel_session() is called in `tree_exiting`). Confirm signal connections are disconnected before `queue_free` or use `CONNECT_ONE_SHOT` where appropriate.
- Duration selector UI on mobile (720px width): SpinBox may be too small to tap accurately. Mitigation: use an HSlider with a Label showing the current value, which is easier to interact with on touch screens.
- SchoolScene Player spawn position: Player must be placed at a position that does NOT overlap the classroom entry Area2D on scene load, otherwise the trigger fires immediately. Mitigation: set the classroom Area2D trigger near the door rather than at the room center.
