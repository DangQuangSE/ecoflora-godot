# Phase 1: Domain + Service

## Layer
`domain/` and `services/` — no Node dependencies, no autoload imports.

## Files

| File path | Layer | Action |
|---|---|---|
| `domain/DailyTask.gd` | domain | CREATE |
| `domain/TaskProgress.gd` | domain | CREATE |
| `services/DailyTaskService.gd` | services | CREATE |

## Requirements
Provide the typed data classes and the network service layer that the rest of the system depends on — parsing API responses into domain objects and issuing the claim HTTP call — so that upper layers (autoloads, scenes) never touch raw Dictionaries from the server.

## Steps
1. Create `DailyTask` as a `RefCounted` class with typed fields for all task definition data: stable string `id`, display strings (`title`, `description`), task type as an integer constant (`GARDEN_CARE=0`, `HARVEST=1`, `FOCUS_SESSION=2`, `ONLINE_TIME=3`), `action_subtype` string (e.g. `"water"`), numeric `target`, cycle constant (`DAILY=0`, `WEEKLY=1`), and reward fields (`reward_currency`, `reward_item_id`, `reward_item_qty`, `reward_xp`). Add a `from_dict(d: Dictionary) -> DailyTask` static factory for clean parsing.

2. Create `TaskProgress` as a `RefCounted` class with fields: `task_id: String`, `progress: int`, `claimed: bool`, `period_start: int` (Unix epoch). Add `to_dict() -> Dictionary` and `from_dict(d: Dictionary) -> TaskProgress` for local file serialization. Include a computed helper `is_complete(target: int) -> bool` that returns `progress >= target`.

3. Create `DailyTaskService` as a plain `RefCounted` (not a Node). Add `parse_tasks(task_arr: Array, progress_arr: Array) -> Dictionary` that returns `{ "tasks": Array[DailyTask], "progress": Array[TaskProgress], "server_time": int }` — consuming the raw JSON arrays from the GET response. Use `DailyTask.from_dict` and `TaskProgress.from_dict` internally.

4. Add `fetch_async(http: HTTPRequest, base_url: String, token: String) -> Dictionary` to `DailyTaskService`. It performs `GET /api/daily-tasks` with the Bearer token header, handles HTTP errors (401 → empty dict, other errors → empty dict with `push_warning`), and returns the parsed result from `parse_tasks` on success or an empty Dictionary on failure.

5. Add `claim_async(http: HTTPRequest, base_url: String, token: String, task_id: String) -> Dictionary` to `DailyTaskService`. It `POST`s to `/api/daily-tasks/{task_id}/claim` with a Bearer header and empty body, awaits `http.request_completed`, returns the parsed response dictionary on HTTP 200 (containing `newCurrencyTotal`, `newUserXP`, `newUserLevel`, `rewardItemId`, `rewardItemQty`), or an empty Dictionary on failure. 401 triggers a `push_warning` — caller (TaskManager) decides whether to call `UserManager.handle_401()`.

6. Add a `build_offline_fallback() -> Array[DailyTask]` static method to `DailyTaskService` that returns a hardcoded array of 5 daily + 3 weekly placeholder tasks (using the known stable IDs from the spec). These are display-only when the server is unreachable; they carry zero reward values and the UI will show them as non-claimable until a real GET succeeds.

## Success Criteria
- `DailyTask.from_dict` round-trips a sample server JSON dict without losing any field
- `TaskProgress.to_dict` / `from_dict` round-trips losslessly (all fields preserved including `period_start`)
- `TaskProgress.is_complete(3)` returns `true` when `progress == 3`, `false` when `progress == 2`
- `DailyTaskService.parse_tasks` called with an empty array returns `{ "tasks": [], "progress": [], "server_time": 0 }` without errors
- No `Node`, `get_tree()`, `$child`, or autoload reference appears anywhere in `domain/` or `services/DailyTaskService.gd`

## Risks
- Server may return task `type` as a string enum (`"GARDEN_CARE"`) rather than an integer. Mitigation: `from_dict` normalizes string → int via a local lookup dictionary before assigning to the typed field.
- `period_start` from server may be an ISO-8601 string rather than a Unix epoch integer. Mitigation: `TaskProgress.from_dict` checks the value type; if it is a string, converts via `Time.get_unix_time_from_datetime_string`.
