# Phase 4: HUD Wiring + Plot Tap Handler + Confirm Dialog

## Requirements

Wire the ShovelButton to toggle dig_up_mode via InteractionManager. Add dig-up tap logic in Plot.gd that triggers a confirm dialog when dig_up_mode is active and an occupied plot is tapped. Only call GardenManager.dig_up() after the player confirms the dialog.

## Steps

1. **Verify ShovelButton actually exists in the scene tree** — Before wiring anything, open `scenes/hud/HUD.tscn` and confirm a node named `ShovelButton` exists as a child of `RightIconGrid` (the screenshot shows the icon rendering, but that doesn't guarantee the node path `$RightIconGrid/ShovelButton` is correct — it could be nested differently or named something else). If it doesn't exist at that exact path, add it in the editor (52×52, matching HarvestButton's size/anchors) before continuing. Skipping this check means `@onready var _shovel_btn` silently resolves to null and the feature does nothing with no error.

2. **Wire ShovelButton in HUD.gd** — In `d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\scenes\hud\HUD.gd`, find line 42 where `_harvest_btn.pressed.connect(InteractionManager.toggle_harvest_mode)`. Add immediately after (around line 43): 
   ```gdscript
   var shovel_btn: Button = $RightIconGrid/ShovelButton
   if shovel_btn:
       shovel_btn.pressed.connect(InteractionManager.toggle_dig_up_mode)
   ```
   Alternatively, add `@onready var _shovel_btn: Button = $RightIconGrid/ShovelButton` near the top (around line 20 with other button nodes), then in `_ready()` add connection. Either approach is fine; choose the style matching the codebase.

3. **Add dig_up_mode visual feedback** — Mirror the harvest mode highlight (line 164: `_harvest_btn.modulate = Color(1.0, 0.75, 0.2, 1.0) if active else Color.WHITE`). Add a new signal handler:
   ```gdscript
   InteractionManager.dig_up_mode_changed.connect(_on_dig_up_mode_changed)
   ```
   and implement the handler to highlight ShovelButton when active (same color as harvest or a different one, e.g., Color(0.8, 0.6, 0.2, 1.0) for a brownish tone matching shovel theme). Do NOT yet add the signal itself to InteractionManager — that comes when you wire the mode refactor in Phase 2 to emit this new signal (as a bonus beyond the base requirements).

   _Alternative simple approach:_ Skip the new signal and just highlight via the existing harvest_mode_changed signal by checking `InteractionManager.is_dig_up_mode()` (but this is less clean). Recommend adding a `dig_up_mode_changed(active: bool)` signal in Phase 2.

4. **Add dig-up tap handler to Plot.gd** — In `d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\scenes\garden\Plot.gd` (class PlotNode), modify the `_on_plot_gui_input()` function (line 67). After the existing harvest check (lines 80–81), add an `elif` for dig_up:
   ```gdscript
   elif InteractionManager.is_dig_up_mode() and _current_plot.is_occupied:
       _try_dig_up()
   ```

5. **Implement _try_dig_up() function** — Add a new function after `_try_harvest()` (around line 129). **Critical:** `await dialog.confirmed` alone will hang forever if the player cancels instead (cancel emits `cancelled`, not `confirmed`). Confirmed by reading `scenes/ui/components/dialog/BaseDialog.gd:60-74`: `dismiss(accepted)` emits `confirmed` or `cancelled` first, then tweens out, then unconditionally calls `queue_free()` on BOTH paths — so `dialog.tree_exited` is guaranteed to fire exactly once regardless of which button was pressed. Await that instead of `confirmed` directly, and read which one happened via two one-shot signal connections setting a local flag:
   ```gdscript
   func _try_dig_up() -> void:
       if _current_plot == null or not _current_plot.is_occupied or _current_plot.is_pending_sync or _current_plot.current_plant == null:
           return
       var template: FlowerTemplate = GardenManager.get_templates().get(
           _current_plot.current_plant.flower_template_id, null) as FlowerTemplate
       if template == null:
           return
       var flower_name: String = template.name.replace("_", " ") if template.name else "Hoa"
       var dialog: BaseDialog = BaseDialog.show_confirm(
           self,
           "Xúc cây",
           "Bạn chắc chắn muốn xúc %s? Hành động này sẽ mất toàn bộ stage/XP đã trồng.\nCây sẽ trở thành hạt giống Lv0." % flower_name,
           "Xúc",
           "Hủy"
       )
       if dialog == null:
           push_error("PlotNode._try_dig_up: BaseDialog instantiation failed")
           return
       var result := [false]  # boxed in Array (reference type) — a plain bool local would be captured BY VALUE in
                               # the lambdas below, so func(): confirmed = true would never propagate to the outer
                               # scope (caught by IDE as CONFUSABLE_CAPTURE_REASSIGNMENT during actual implementation)
       dialog.confirmed.connect(func(): result[0] = true, CONNECT_ONE_SHOT)
       dialog.cancelled.connect(func(): result[0] = false, CONNECT_ONE_SHOT)
       await dialog.tree_exited  # dialog frees itself on either confirm or cancel — resumes exactly once either way
       if result[0]:
           InteractionManager.request_plot_action(plot_id, "dig_up", {})
   ```

6. **Add dig_up action dispatcher** — In the `_on_plot_action()` handler in `d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\autoloads\GardenManager.gd` (around line 719), add a new case in the match statement (after "harvest"):
   ```gdscript
   "dig_up": dig_up(plot_id)
   ```

7. **Double-tap guard** — Already folded into the `_try_dig_up()` guard clause in step 5 (`_current_plot.is_pending_sync` check before showing the dialog). No separate change needed; this step just confirms it's present — don't drop that clause when implementing.

8. **Verify plot sprite input configuration** — Ensure that the plot_sprite ColorRect (line 14 in Plot.gd) has mouse_filter set to allow input. The existing code already has `plot_sprite.gui_input.connect(_on_plot_gui_input)` (line 22), which should work; no changes needed unless dig-up input is not being received.

9. **Test dialog animation** — The BaseDialog.tscn has pop-in/pop-out animations defined in BaseDialog.gd (lines 39–47, 66–71). Verify that when dialog is shown via show_confirm(), it animates in correctly and blocks input to the garden during display. No code changes needed; just verify the CanvasLayer layer = 200 is higher than the garden layer so it appears on top.

## Success Criteria

- ShovelButton has a pressed signal handler that calls `InteractionManager.toggle_dig_up_mode()`.
- ShovelButton modulate changes to a highlight color when dig_up_mode is active; returns to white when inactive.
- Tapping an occupied plot while dig_up_mode is active shows a BaseDialog with title "Xúc cây" and a message warning about stage/XP loss, with "Xúc" and "Hủy" buttons.
- Dialog displays the flower's proper name (e.g., "Rose" not "rose") via template.name replacement.
- Clicking "Xúc" button emits confirmed signal, dismisses dialog, and calls `InteractionManager.request_plot_action(plot_id, "dig_up", {})`.
- Clicking "Hủy" button emits cancelled signal, dismisses dialog, and does NOT call dig_up action; plot remains occupied.
- Cancelling the dialog does NOT leave `_try_dig_up()` permanently suspended — the coroutine resumes and returns cleanly on cancel, same as on confirm (verify by cancelling 5+ times in a row and confirming no growing list of stuck calls / memory growth).
- Tapping an empty plot in dig_up_mode does nothing (plot_sprite input is ignored or no _try_dig_up call).
- Tapping an occupied plot while NOT in dig_up_mode shows flower info (existing behavior, unchanged).
- Double-tapping during dialog animation does not show two dialogs or corrupt the plot state.
- After successful dig_up (Phase 3 success), dig_up_mode remains active and player can tap another occupied plot to dig_up again without re-toggling the button.

## Risks

- **Dialog lifecycle** — If player closes the app while dialog is open, BaseDialog.queue_free() may not finalize correctly. Mitigation: BaseDialog creates its own CanvasLayer and connects tree_exited to queue_free the canvas; this should clean up automatically. Test by closing game mid-dialog.
- **Input blocking** — If the dialog's backdrop ColorRect doesn't have `mouse_filter = MOUSE_FILTER_STOP`, input events might pass through to the garden. Mitigation: Verify BaseDialog.tscn has backdrop with mouse_filter set correctly; test by tapping outside dialog and confirming plot doesn't respond.
- **Signal await without null check** — If show_confirm() returns null due to missing scene file, `await dialog.confirmed` will crash. Mitigation: Code already checks `if dialog == null` and returns early; error is logged.
- **Flower template lookup fails** — If template is null (should not happen if data is consistent), _try_dig_up returns early and does nothing. Mitigation: This is safe; player simply can't dig that plot (graceful degradation). Log warning via push_warning() to help debug.
