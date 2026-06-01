# Phase 4: Godot Autoloads

**Layer:** autoloads/ (Godot — GDScript)
**Stories:** P1 (reward items reach inventory), FR-03 (remove XP bulk on success path)

## Requirements
Wire the new `rewardItems` array from the BE response through the autoload signal chain so that `InventoryManager` applies item grants and `GardenManager` no longer applies XP on focus success. Fail path (-20 XP penalty) must remain untouched.

## Files

| File | Action | Purpose |
|------|--------|---------|
| `autoloads/FocusManager.gd` | Edit | Update `_fire_terminal_async()` to use new `Dictionary` return from `complete_async`; add `session_reward_received(items: Array)` signal; emit it on success |
| `autoloads/GardenManager.gd` | Edit | Remove `apply_focus_xp_bulk(minutes)` from `_on_focus_session_completed()`; add `_on_focus_reward_received()` stub (no-op); connect to new signal |
| `autoloads/InventoryManager.gd` | Edit | Add `add_reward_item(item_id, item_name, quantity)` method; connect to `FocusManager.session_reward_received` in `_ready()` |

## Steps
1. In `FocusManager.gd`, declare the new signal `session_reward_received(items: Array)` at the top of the file alongside the existing signals.
2. In `_fire_terminal_async()`, change the `ok: bool` variables to `result: Dictionary`. After the `complete_async` await, if `result` is not empty, extract `result.get("rewardItems", [])` and emit `session_reward_received(items)`. Keep `session_completed.emit(minutes)` on the complete path unchanged so `FocusTimerUI`'s existing ONE_SHOT connection still fires. For the `fail_async` path, no reward signal is emitted — only the existing `session_failed` signal path applies.
3. In `GardenManager.gd`, replace the body of `_on_focus_session_completed(minutes: int)` — remove the `apply_focus_xp_bulk(minutes)` call. Add a new `_on_focus_reward_received(items: Array) -> void` method (body can be empty for now). In `_ready()`, connect `FocusManager.session_reward_received` to `_on_focus_reward_received`. Leave `_on_focus_session_failed()` and its `apply_focus_xp_bulk(-20)` call completely unchanged.
4. In `InventoryManager.gd`, add `func add_reward_item(item_id: String, item_name: String, quantity: int) -> void`. Inside: find an existing item by `reference_id == item_id`; if found increment its `quantity`; if not found create a new `InventoryItem` with `category = CONSUMABLE`, `reference_id = item_id`, `name = item_name`, `quantity = quantity`, and append it to `_inventory.items`. Emit `inventory_updated` at the end.
5. In `InventoryManager._ready()`, connect `FocusManager.session_reward_received` to a local handler that iterates the items array and calls `add_reward_item()` for each entry, reading `item_id`, `item_name`, and `quantity` from each Dictionary element with `.get()` and a safe default. After connecting, assert the return is `OK`: `assert(FocusManager.session_reward_received.connect(_on_focus_reward_items) == OK, "InventoryManager: failed to connect session_reward_received")`. Confirm in `project.godot` that `FocusManager` autoload is listed BEFORE `InventoryManager` so it is initialized first.

## Success Criteria
- After a completed focus session (non-mock), `InventoryManager.get_inventory()` contains Watering Can entries with quantity increased by the expected amount
- `GardenManager._on_focus_session_completed` no longer calls `apply_focus_xp_bulk` (verify by grepping the file)
- After a failed focus session (3 violations), `apply_focus_xp_bulk(-20)` still fires and NO `session_reward_received` is emitted
- Godot prints no errors (`push_error`) or script errors in the Output panel during either path

## Risks
- `session_completed` emits before `_fire_terminal_async` finishes (it's a fire-and-forget coroutine); `session_reward_received` arrives after UI is already showing result panel — Phase 5 handles this by connecting to `session_reward_received` instead of reading data inside `_on_session_completed`
- `InventoryItem` lookup by `reference_id` must match the UUID string exactly (case-sensitive) — use the same UUID strings from `RewardCalculationService`
