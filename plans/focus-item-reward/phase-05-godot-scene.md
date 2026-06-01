# Phase 5: Godot Scene

**Layer:** scenes/ (Godot — GDScript + TSCN)
**Stories:** P1 (player sees received items), FR-04 (item list replaces "+X XP" text)

## Requirements
Replace the single `ResultLabel` in `FocusTimerUI` with a scrollable item list that shows each rewarded item's name and quantity. The fail result still shows the "-20 XP penalty" text. If `rewardItems` arrives after the panel is already visible, the list updates in place.

## Files

| File | Action | Purpose |
|------|--------|---------|
| `scenes/school/FocusTimerUI.tscn` | Edit | Replace `ResultLabel` with a `VBoxContainer` (`RewardList`) inside `ResultBox`; add a separate `ResultLabel` for fail text only |
| `scenes/school/FocusTimerUI.gd` | Edit | Connect to `FocusManager.session_reward_received`; populate `RewardList` on receipt; show fail label only on fail path |

## Steps
1. In `FocusTimerUI.tscn`, inside `ResultBox`, replace the single `ResultLabel` node with a `VBoxContainer` named `RewardList` and add a sibling `Label` named `FailLabel` (hidden by default). Keep `ReturnButton` as the last child.
2. In `FocusTimerUI.gd`, add `@onready` references for `_reward_list: VBoxContainer` and `_fail_label: Label`. Remove the `@onready` for `_result_label` (it no longer exists).
3. In `_ready()`, guard the connection before adding it: `if not FocusManager.session_reward_received.is_connected(_on_reward_received): FocusManager.session_reward_received.connect(_on_reward_received)`. This prevents double-connections if the node re-enters the tree without being freed. Disconnect in `_exit_tree()` with a matching `is_connected` guard.
4. In `_on_session_completed(minutes: int)`, show the result panel, clear `_reward_list`, and display a placeholder "Đang nhận phần thưởng…" label inside `RewardList` until `_on_reward_received` fires and replaces it.
5. In `_on_reward_received(items: Array)`, clear `_reward_list`, then for each Dictionary in `items` create a `Label` child showing `"{itemName} x{quantity}"` and add it to `_reward_list`. If `items` is empty, show "Không có phần thưởng (< 25 phút)" instead.
6. In `_on_session_failed()`, show the result panel, hide `_reward_list`, show `_fail_label` with text "-20 XP cho tất cả cây".

## Success Criteria
- Completing a 25-min session shows result panel with at least one label reading "Watering Can x2" (or localised equivalent)
- Completing a session shorter than 25 min shows "Không có phần thưởng" message
- Session fail shows "-20 XP cho tất cả cây" and no reward list entries
- No "+X XP" text appears anywhere in the result panel after this change
- Godot scene opens without script errors in editor

## Risks
- `session_reward_received` arrives asynchronously after PATCH completes; the placeholder label approach in step 4 ensures the UI is never blank while waiting
- ONE_SHOT must NOT be used on the `session_reward_received` connection — reward may conceptually fire once per session but the UI node may be re-entered; use explicit disconnect in `_exit_tree()`
