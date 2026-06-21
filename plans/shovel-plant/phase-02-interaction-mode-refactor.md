# Phase 2: Godot Interaction Mode Refactor (Single Enum)

## Requirements

Replace the current `_harvest_mode: bool` in InteractionManager.gd with a new `enum CurrentMode { NONE, HARVEST, DIG_UP }` and refactor all harvest_mode getters/setters/signals to use the new enum. Ensure modes are mutually exclusive so that enabling dig_up_mode automatically disables harvest_mode and vice versa.

## Steps

0. **Verify full caller surface before touching anything** — Grep the entire Godot project (not just the files this plan assumes) for `is_harvest_mode`, `_harvest_mode`, `toggle_harvest_mode`, and `harvest_mode_changed`. Confirmed so far: HUD.gd, scenes/garden/Plot.gd, and scenes/garden/GardenScene.gd (lines 351, 371 — gate item-drag actions on harvest mode being OFF). Before editing, re-run the grep yourself and list every match found; if any caller outside these three files exists, account for it explicitly in steps 3–8 below instead of assuming the list above is exhaustive.

1. **Define CurrentMode enum** — In `d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\autoloads\InteractionManager.gd` at the top of the class (before signals), add:
   ```
   enum CurrentMode { NONE, HARVEST, DIG_UP }
   ```

2. **Replace bool with enum variable** — Change `var _harvest_mode: bool = false` to `var _current_mode: int = CurrentMode.NONE`. Use int type since GDScript enums are integers.

3. **Update is_harvest_mode() getter** — Modify to return `return _current_mode == CurrentMode.HARVEST`.

4. **Update toggle_harvest_mode()** — Change logic to: if `_current_mode == CurrentMode.HARVEST`, set to NONE; otherwise set to HARVEST. Call `_set_current_mode(_current_mode == CurrentMode.HARVEST ? CurrentMode.NONE : CurrentMode.HARVEST)`.

5. **Refactor _set_harvest_mode() to _set_current_mode()** — Replace the old single-mode setter with a new `func _set_current_mode(mode: int) -> void:`. If new mode equals current mode, return early. Update `_current_mode = mode`. If switching away from any mode, call `InventoryManager.deselect()` (matches existing behavior on harvest-mode exit). Emit `harvest_mode_changed.emit(_current_mode == CurrentMode.HARVEST)` to preserve signal compatibility with existing HUD subscribers.

6. **Add dig_up_mode accessors** — Add `func is_dig_up_mode() -> bool: return _current_mode == CurrentMode.DIG_UP` and `func toggle_dig_up_mode() -> void: _set_current_mode(CurrentMode.DIG_UP if _current_mode != CurrentMode.DIG_UP else CurrentMode.NONE)`.

7. **Preserve signal emissions** — The signal `harvest_mode_changed(active: bool)` must remain and emit true/false based on whether HARVEST mode is active, so existing HUD.gd subscribers don't break. No change needed to signal definition or existing callers; only the internal implementation changes.

8. **Verify UserManager integration** — In `_ready()`, the existing line `UserManager.login_required.connect(func(): _set_harvest_mode(false))` should be updated to `UserManager.login_required.connect(func(): _set_current_mode(CurrentMode.NONE))` to reset all modes on logout.

9. **Update request_plot_action calling site** — This function already exists and is called from Plot.gd; no changes needed here, as it accepts an "action" string parameter which includes "harvest" and will now also include "dig_up".

10. **Add helper for comparing modes** — (Optional, for readability) Add a helper `func _is_mode_active(mode: int) -> bool: return _current_mode == mode` if other code paths need to check modes.

## Success Criteria

- InteractionManager.gd compiles without errors (no undefined symbols, correct enum syntax).
- `is_harvest_mode()` returns true only when `_current_mode == CurrentMode.HARVEST`, false otherwise.
- `is_dig_up_mode()` returns true only when `_current_mode == CurrentMode.DIG_UP`, false otherwise.
- Calling `toggle_harvest_mode()` while in DIG_UP mode switches to HARVEST mode (and vice versa); calling twice toggles off.
- Calling `toggle_dig_up_mode()` while in HARVEST mode switches to DIG_UP mode (and vice versa); calling twice toggles off.
- Existing HUD.gd subscribers to `harvest_mode_changed` signal receive correct bool values (true when HARVEST active, false otherwise).
- UserManager logout resets mode to NONE via the connection update.
- No runtime assertion or type errors when accessing `_current_mode` as an int.

## Risks

- **Signal subscriber breakage** — If other code (beyond HUD.gd) assumes `harvest_mode_changed` is only emitted when entering/exiting harvest, and now receives it when switching between modes. Mitigation: Grep codebase for all subscribers to `harvest_mode_changed`; verify they only check the bool value (true = any mode off, false = any mode off is fine); update any booleans of internal state they maintain.
- **Enum value persistence in saved data** — If _current_mode was ever saved to disk/config, old int values (0, 1) might not map to new enum after code changes. Mitigation: Mode is runtime-only, never persisted; safe to refactor. Verify no code tries to load _current_mode from save files.
- **Enum not exported** — GDScript enums defined inside a class are not accessible from outside unless explicitly nested or exported. Mitigation: Enum is only used within InteractionManager; callers use the public `is_harvest_mode()` / `is_dig_up_mode()` / `toggle_*()` functions, so no exposure risk.
