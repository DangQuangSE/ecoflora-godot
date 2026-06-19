# Phase 3: UI Panel

## Layer
`scenes/` — Control nodes, connects to TaskManager autoload only. No direct service or domain imports.

## Files

| File path | Layer | Action |
|---|---|---|
| `scenes/daily_task/DailyTaskPanel.tscn` | scenes | CREATE |
| `scenes/daily_task/DailyTaskPanel.gd` | scenes | CREATE |
| `scenes/daily_task/TaskCard.tscn` | scenes | CREATE |
| `scenes/daily_task/TaskCard.gd` | scenes | CREATE |
| `scenes/hud/HUD.tscn` | scenes | MODIFY |
| `scenes/hud/HUD.gd` | scenes | MODIFY |

## Requirements
Players can open a Daily Task panel from the HUD, view all daily and weekly tasks with live progress bars, and tap a claim button on any completed task to receive rewards — with the button switching to a disabled "Claimed" state immediately on tap and reverting only if the server rejects the claim.

## Steps
1. Design `TaskCard.tscn` as a `PanelContainer` sized to match existing card conventions (full-width inside a scroll container, ~80px tall). Child nodes: a `TextureRect` for the task icon, a `VBoxContainer` holding a `Label` for title and a `HBoxContainer` with a `ProgressBar` and a progress `Label` (`"X / N"`), and a `Button` for claiming. Export `@export` variables for icon texture, title text, progress value, target value, and a `is_claimed` bool so the Inspector can preview states.

2. Design `DailyTaskPanel.tscn` with a **`Control` as its root node** (not a CanvasLayer — HUD already provides a CanvasLayer context; nesting another CanvasLayer inside creates z-ordering conflicts with ShopScene). Set the root Control's `anchor_left = anchor_right = 0.5`, `anchor_top = anchor_bottom = 0.5`, sized to 720×920 (same pattern as ShopScene). Child nodes: a `BGDimmer` `ColorRect`, a `PanelContainer` for the panel body, a tab row `HBoxContainer` with two `Button`s ("Daily" and "Weekly"), a `ScrollContainer` + `VBoxContainer` for the task card list, and a `CloseButton`. The panel starts `visible = false`.

3. Implement `DailyTaskPanel.gd` extending `Control`. In `_ready`, connect to `TaskManager.tasks_updated`. On `show_panel(tab: int)` set `visible = true` and call `_rebuild_list(tab)`. On close button pressed, set `visible = false`. Tab buttons call `_rebuild_list(0)` or `_rebuild_list(1)`.

4. Implement `_rebuild_list(cycle: int)` in `DailyTaskPanel.gd`. Clear the `VBoxContainer` children. Filter `TaskManager`'s current tasks by `cycle` constant. For each task, instantiate a `TaskCard`, populate its exported fields from the matching `TaskProgress`, and connect the card's `claim_pressed` signal to `_on_claim_pressed(task_id)`. Use `TaskManager.tasks_updated` to call `_rebuild_list` with the current tab when the panel is already visible, so progress bars refresh in real time.

5. Implement `_on_claim_pressed(task_id: String)` in `DailyTaskPanel.gd`. Immediately disable the claim button on that card (optimistic lock). Call `TaskManager.claim_task_async(task_id)` (fire-and-forget, no await in the UI). Connect to `TaskManager.claim_result_received` to re-enable the button if the result is `false`. If `true`, the button text changes to "Claimed" and stays disabled (driven by the next `tasks_updated` emit).

6. Add a "Tasks" `Button` to `HUD.tscn` alongside the existing Shop button. In `HUD.gd`, add `@onready var _task_panel: Control = $DailyTaskPanel` and `@onready var _task_btn: Button = $TaskButton`. In `_ready`, connect `_task_btn.pressed` to `_open_tasks`. Implement `_open_tasks()` to call `_task_panel.show_panel(0)`. Add `DailyTaskPanel` as a child scene of HUD (same placement as ShopScene).

7. Implement `TaskCard.gd` to drive its own child nodes from the exported fields. Declare a `signal claim_pressed` that the card emits when the claim `Button` is pressed. In `_ready`, set the progress bar `max_value` to `target`, `value` to `progress`, label text to `"%d / %d" % [progress, target]`. If `is_claimed` is true, set button text to "Da nhan", disable it, and set button modulate to grey. If `progress >= target` and not claimed, enable button and set text to "Nhan". Otherwise disable button and set text to "Chua xong".

## Success Criteria
- Opening the Daily tab shows at least 3 task cards with correct title, X/N progress text, and claim button state
- Completing a garden care action while the panel is open updates the progress bar live (without closing and reopening)
- Tapping "Nhan" on a completed task disables the button instantly (same frame, before any network call)
- Switching between Daily and Weekly tabs shows the correct subset of tasks with no ERR_BUSY or crash
- The panel closes cleanly when the close button is pressed; pressing the HUD Tasks button reopens it at the Daily tab
- No direct call to `DailyTaskService`, `DailyTask`, or `TaskProgress` class names appears in any scene script

## Risks
- Rapid tab switching while `tasks_updated` fires mid-rebuild could corrupt the card list if `_rebuild_list` is not idempotent. Mitigation: clear children at the start of every `_rebuild_list` call before instantiating new cards; do not check for existing cards.
- `CanvasLayer` anchor positioning: use `anchor_left = anchor_right = 0.5`, `anchor_top = anchor_bottom = 0.5`, not `CenterContainer`, to match the established pattern from `feedback_godot_canvas_layer.md` memory.
- `DailyTaskPanel` added as a child of HUD shares the same CanvasLayer as ShopScene — ensure both panels are not simultaneously visible (close one before opening the other).
