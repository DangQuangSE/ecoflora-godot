# Phase 3: GardenScene Wiring

## Requirements

This phase integrates the weather NPC reminder into GardenScene.gd by subscribing to WeatherManager.weather_changed, implementing session-level condition dedupe, guarding against boot-emit spurious triggers, and instantiating WeatherNpcBubble on valid condition changes. The wiring follows the existing UnlockBanner pattern in GardenScene.gd (lines 17-19, 207-226), maintaining consistency with current architecture.

## Steps

1. Add instance variables to GardenScene.gd: `_active_weather_bubble: WeatherNpcBubble = null`, `_last_shown_condition: WeatherState.Condition = -1` (invalid sentinel), `_is_first_weather_signal: bool = true` (boot-emit guard flag).

2. In `_ready()` function, after existing signal connections, subscribe to WeatherManager.weather_changed: `WeatherManager.weather_changed.connect(_on_weather_changed)`.

3. Implement `_on_weather_changed(new_state: WeatherState) -> void` handler: guard `if new_state == null: return` first (defensive, matches `is_instance_valid` discipline used elsewhere in this file). Then check and skip if `_is_first_weather_signal` is true (set flag to false after check), preventing spurious bubble on app startup.

4. In handler, compare `new_state.condition` against `_last_shown_condition`; if identical, return early (session-level dedupe — don't re-show for same condition).

5. If condition differs, update `_last_shown_condition = new_state.condition`, call WeatherNpcMessageCatalog.get_random_message(new_state.condition) to fetch a message.

6. Before instantiating a new bubble: if `_active_weather_bubble != null and is_instance_valid(_active_weather_bubble)`, call `_active_weather_bubble.queue_free()` and clear the reference first — prevents orphaning a still-visible bubble if weather changes again (e.g. SUNNY → RAINY → CLOUDY) before the previous one auto-hid.

7. Instantiate WeatherNpcBubble.tscn (add to scene tree via preload and `get_tree().root.add_child()`), call `show_message(message)` on the instance.

8. Store reference in `_active_weather_bubble`, connect optional `dismissed` signal from bubble to `_on_weather_bubble_dismissed()` to clear reference when bubble auto-hides or is manually dismissed.

9. In `_exit_tree()`, add cleanup: disconnect WeatherManager.weather_changed, check `if _active_weather_bubble != null and is_instance_valid(_active_weather_bubble)` and queue_free it (matching UnlockBanner cleanup pattern at lines 245-247, explicit `is_instance_valid` per that precedent).

10. Test manually: set WeatherManager.mock_condition in Inspector to different values (SUNNY → RAINY → CLOUDY → STORM) while in GardenScene, verify bubble appears with correct message and doesn't re-appear on re-entry with same condition; verify boot-emit guard by launching app and observing no bubble before reaching GardenScene; verify rapid condition changes (toggle mock_condition quickly 2-3 times) don't leave orphaned bubbles on screen.

## Success Criteria

- [ ] WeatherManager.weather_changed subscription wired in GardenScene._ready(), handler called on condition changes.
- [ ] Boot-emit guard works: `_is_first_weather_signal` skips first emit after _ready(), no bubble appears on app startup before user reaches GardenScene.
- [ ] Session-level dedupe active: changing weather to condition A shows bubble; navigating away and back to GardenScene with same condition A does not re-trigger bubble; changing to condition B triggers bubble again.
- [ ] Each condition change (SUNNY → RAINY, RAINY → CLOUDY, etc.) produces bubble with random message from WeatherNpcMessageCatalog pool.
- [ ] Bubble instantiation follows UnlockBanner pattern: preloaded scene, get_tree().root.add_child(), signal connection for cleanup.
- [ ] Instance variables (_active_weather_bubble, _last_shown_condition, _is_first_weather_signal) initialized with correct types and sentinel values.
- [ ] _exit_tree() disconnects WeatherManager signal and queue_frees bubble if valid (no memory leaks or orphaned signals).
- [ ] `_on_weather_changed` returns early on `new_state == null` without crashing.
- [ ] Rapid condition changes (e.g. SUNNY → RAINY → CLOUDY within a few seconds) free the previous bubble before showing the next — no orphaned/stacked bubbles on screen.
- [ ] Manual test via Inspector: WeatherManager.mock_condition toggle triggers correct behavior (message appears, dedupe works, no boot-spam).
- [ ] When WeatherManager.use_mock = true and mock_condition is changed, _on_weather_changed fires and logic executes (already available in WeatherManager, just needs to be used).

## Risks

- WeatherManager.weather_changed emitted before GardenScene subscribes (race condition) — **Mitigation:** WeatherManager is autoload and initialized early (line 50 _ready), GardenScene._ready calls connect() at line 25+, boot-emit already emitted by then but guarded by `_is_first_weather_signal` flag; no race.
- Bubble created while WeatherNpcBubble.tscn is loading/not preloaded → **Mitigation:** Preload at top of GardenScene.gd (add `const WeatherNpcBubbleScene := preload("res://scenes/garden/WeatherNpcBubble.tscn")`).
- Multiple bubbles spawn if handler called multiple times per condition change — **Mitigation:** Dedupe logic checks `_last_shown_condition` before instantiation; only one bubble per unique condition per phase.
- Bubble orphaned when a new condition arrives before the previous bubble auto-hid — **Mitigation:** Step 6 explicitly queue_frees `_active_weather_bubble` (if valid) before instantiating the next one.
- Disconnect from WeatherManager fails in _exit_tree if signal already invalid — **Mitigation:** Use `if WeatherManager.weather_changed.is_connected(_on_weather_changed)` guard before disconnect (pattern used in GardenScene lines 235-244).
- Message pool returns fallback for unknown condition, confusing player — **Mitigation:** WeatherState.Condition enum only has 4 values; Phase 1 explicitly covers all 4; if enum extended (P3 out-of-scope), Phase 1 push_error logs unknown condition; spec excludes enum extension.
