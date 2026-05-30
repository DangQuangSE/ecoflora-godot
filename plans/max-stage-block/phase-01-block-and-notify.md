# Phase 1: Block and Notify

## Layer
scenes/

## Files

| File | Layer | Change |
|---|---|---|
| `scenes/garden/FloatLabel.gd` | scenes | Add optional `color` param to `play()`, apply it via `add_theme_color_override` |
| `scenes/garden/Plot.gd` | scenes | Update `_spawn_float_label()` to accept+forward color; add max-stage guard in `_apply_item()` |

## Requirements
Delivers all three P1/P2 user stories: care actions are silently blocked at max stage, the player sees a red/orange floating label instead of the normal +XP yellow label, and all three care item types (water, fertilize, pesticide) are covered.

## Steps
1. Extend `FloatLabel.play()` with an optional `color` parameter defaulting to the existing yellow, and apply it to the label node so callers that pass no color see no change.
2. Update `_spawn_float_label()` in `Plot.gd` to accept an optional color parameter and forward it to `FloatLabel.play()`.
3. In `_apply_item()`, before the CONSUMABLE dispatch block resolves to any action (both BE cache path and mock fallback path), look up the plant's template and compare `current_stage` against `template.get_max_stage_level()`.
4. If the plant is at max stage, call `_spawn_float_label("ĐÃ ĐẠT LEVEL TỐI ĐA", Color(1.0, 0.4, 0.1, 1.0))` and return early — no item consumed, no API call made.
5. Verify the existing `_on_plant_xp_gained` call to `_spawn_float_label` still compiles and shows yellow (no color arg passed).

## Success Criteria
- Applying any care item to a max-stage plant shows the orange label, item quantity unchanged, no network request logged
- Applying any care item to a non-max-stage plant still works normally (yellow +XP label, item consumed, API called)
- FloatLabel yellow default used everywhere else is visually unchanged

## Risks
- Template lookup returns null (plant has no template): guard with an early return before the stage check, same pattern already used in `_try_harvest()` — no new risk introduced
