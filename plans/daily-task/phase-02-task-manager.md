# Phase 2: Task Manager Autoload

## Layer
`autoloads/` (TaskManager singleton) and a small modification to `autoloads/GardenManager.gd`.

## Files

| File path | Layer | Action |
|---|---|---|
| `autoloads/GardenManager.gd` | autoloads | MODIFY |
| `autoloads/TaskManager.gd` | autoloads | CREATE |
| `project.godot` | config | MODIFY |

## Requirements
All in-game actions that count toward task progress must emit signals that TaskManager intercepts synchronously, so that progress updates reach the UI in under 16ms without any network call. TaskManager also owns the online-time accumulator and the local persistence file.

## Steps
1. In `GardenManager.gd`, declare `signal care_completed(plot_id: String, action_type: int)` at the top of the file alongside existing signals. Then:
   - Add `action_type: int` as a **third parameter** to `_mock_care(plot_id: String, base_xp: int, action_type: int)`. Update all three callers: `water()` passes `0`, `fertilize()` passes `1`, `pesticide()` passes `2`. Emit `care_completed.emit(plot_id, action_type)` at the very end of `_mock_care`, after `plot.is_pending_sync = false`.
   - In `_care_action()`, emit `care_completed.emit(plot_id, action_value)` **only in the success branch** — inside the `if` block where `_care_apply_server_response()` returns `true`, before `plots_updated.emit(_plots)`. Do NOT emit in the rollback path or after `_care_rollback()`. This mirrors the `harvest_completed` pattern.

2. Create `autoloads/TaskManager.gd` extending `Node`. Declare signals: `tasks_updated(tasks: Array, progress: Array)` and `claim_result_received(task_id: String, success: bool)`. Declare `@export var use_mock: bool = false`. Add typed instance variables for: the tasks array, the progress dictionary (keyed by `task_id`), the online-minutes counter for today, the accumulated delta float, the server reset epoch stored locally, and the in-flight claim flag.

3. In `TaskManager._ready()`, preload `DailyTaskService`, instantiate two `HTTPRequest` nodes (one for fetch, one for claim), connect to `GardenManager.care_completed`, `GardenManager.harvest_completed`, `FocusManager.session_completed`, and `UserManager.login_succeeded`. Call `set_process(false)` initially — the online timer only runs after login. Load cached progress from `user://daily_task_progress.json` immediately so tasks show stale-but-present data before the GET completes.

4. In the `_on_login_succeeded` handler, call `set_process(true)` to start the online timer, then `await` the fetch coroutine (`DailyTaskService.fetch_async`). After a successful GET, compare the returned `server_time` to `last_reset_epoch`: if the server time falls in a new daily period (past 7AM UTC+7) reset all non-weekly progress and claimed flags; if in a new weekly period (past Monday 7AM UTC+7) reset weekly tasks too. Merge the authoritative server progress into the local progress dict, save to disk, and emit `tasks_updated`.

5. In `_process(delta)`, accumulate delta into a float counter. When it reaches 60.0 seconds (one minute), increment the online-minutes counter for the `ONLINE_TIME` task, reset the counter, call the internal `_on_progress_increment("online_time", 1)` helper, and save to disk.

6. Implement the three signal handlers (`_on_care_completed`, `_on_harvest_completed`, `_on_session_completed`) each calling `_on_progress_increment` with the matching task type and subtype. `_on_progress_increment` iterates the task list, finds tasks that match type+subtype and are not yet `claimed` and not yet at `target`, increments `progress` by the given amount (clamped to target), saves to disk, and emits `tasks_updated`.

7. Implement `claim_task_async(task_id: String) -> void`. Guard with `_claim_in_flight` flag. Set `is_pending_sync` locally (optimistic: mark UI as "claiming"). Await `DailyTaskService.claim_async`. On success, call `UserManager.update_currency`, `UserManager.apply_server_xp`, and `InventoryManager.add_reward_item(item_id, "", qty)` for any item reward from the response. (`InventoryManager.add_item` does not exist — `add_reward_item` is the correct method.) Mark the local `TaskProgress.claimed = true`, save to disk, emit `tasks_updated`, emit `claim_result_received(task_id, true)`. On failure, emit `claim_result_received(task_id, false)` and do not alter the claimed flag.

8. Register `TaskManager` in `project.godot` under `[autoload]` **after `InventoryManager`** (TaskManager calls `InventoryManager.add_reward_item` in the claim path — InventoryManager must be fully initialized first; InventoryManager itself loads after FocusManager, so FocusManager.session_completed will also be available). Actual load order: `...FocusManager → InventoryManager → TaskManager → ItemIconRegistry...`. Entry: `TaskManager="*res://autoloads/TaskManager.gd"`.

## Success Criteria
- After `GardenManager.water()` succeeds, `TaskManager` progress for any `GARDEN_CARE / water` task increments by 1 within the same frame
- `user://daily_task_progress.json` is written on disk and contains the updated progress after each increment
- Online timer accumulates 1 minute of progress for every 60 real seconds while `_process` is running
- `claim_task_async` called twice in rapid succession only fires the network request once (second call blocked by `_claim_in_flight`)
- After logout + re-login, TaskManager reloads the cached progress from disk and emits `tasks_updated` with the pre-GET data so the UI is not blank
- `GardenManager.care_completed` is NOT emitted when the care action rolls back (server 4xx/5xx)

## Risks
- `_process(delta)` runs every frame — the delta accumulation must handle frames where the app is backgrounded (Android may deliver a large delta spike on resume). Mitigation: clamp delta to a max of 2.0 seconds per frame in the accumulator; do not count backgrounded time toward online minutes.
- Connecting to `GardenManager.care_completed` in `_ready` requires GardenManager to be loaded first. Mitigation: project.godot load order already has GardenManager before UserManager; TaskManager loads after UserManager, so GardenManager is guaranteed ready.
- `user://daily_task_progress.json` write on every progress increment could cause micro-stutter on slow Android storage. Mitigation: make the save a deferred call (`call_deferred`) so it runs at end of frame, not mid-signal.
