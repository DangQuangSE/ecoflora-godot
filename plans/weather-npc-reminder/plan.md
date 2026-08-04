# Plan: Weather NPC Reminder

Status: 🟡 In Progress
Date: 2026-08-04
Mode: Hard

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-08-04 (cook session)
**Phase in progress:** none — all 3 phases implemented, awaiting test/review
**Status:** Implementation complete, no local Godot CLI available for headless verification — needs tester/code-reviewer + manual in-editor check

### Decisions made this session
- `domain/WeatherNpcMessageCatalog.gd` created: const Dictionary keyed by `WeatherState.Condition`, 3 Vietnamese messages per condition (SUNNY/CLOUDY/RAINY/STORM), `get_random_message()` static helper with push_error fallback.
- `scenes/garden/WeatherNpcBubble.tscn` + `.gd`: CanvasLayer (layer=9), `PositionRoot` Control repositioned at runtime via `@export vertical_offset/horizontal_offset`, `BubblePanel` (StyleBoxFlat matching UnlockBanner's theme) above `NpcButton` (TextureButton, eco_npc.png). Auto-hide via `get_tree().create_timer` + Tween fade on modulate:a (`await tween.finished` before `queue_free()`, mirrors FloatLabel.gd). Tap dismiss kills tween then queue_free immediately. `tree_exiting` kills any active tween to avoid orphaned tween errors.
- `scenes/garden/GardenScene.gd`: added `_on_weather_changed(new_state)` wired in `_ready()`, mirroring `UnlockBanner`'s pattern (`get_tree().root.add_child`, `dismissed` signal). Boot-emit guard `_is_first_weather_signal`, session dedupe `_last_shown_weather_condition` (int, -1 sentinel), orphan-bubble cleanup before showing a new one on rapid weather changes, full disconnect/cleanup in `_exit_tree()`.
- `godot` CLI not found on this machine (checked PATH and common install dirs) — could not run `--headless --check-only` static check locally; relying on tester/code-reviewer static analysis + user's own Godot editor for runtime verification.

### Next immediate action
Run tester + code-reviewer (Hard mode), then ask user to manually verify in Godot editor via WeatherManager.mock_condition.

## Overview

This plan delivers a friendly NPC reminder system that appears with contextual Vietnamese messages when the weather changes during gameplay in GardenScene. The implementation follows Clean Architecture (domain/services/autoloads/scenes, no upward imports) and mirrors existing patterns (UnlockBanner, FloatLabel, TipCatalog) already in the codebase.

## Phases

- [x] Phase 1: Domain Message Catalog — Create RefCounted message pool per WeatherState.Condition with 2-3 Vietnamese messages each and random-selection helper.
- [x] Phase 2: WeatherNpcBubble Scene & Script — Build CanvasLayer scene (eco_npc sprite + speech bubble), implement auto-hide Tween and tap-to-dismiss via TextureButton.pressed.
- [x] Phase 3: GardenScene Wiring — Subscribe to WeatherManager.weather_changed in _ready(), implement boot-emit guard, session-level dedupe by condition, instantiate bubble on condition change, clean up on exit.

## Research Summary

**Decision:** After architectural comparison, the chosen approach:
- **No new autoload** — dedupe and trigger logic live in GardenScene.gd (mirrors UnlockBanner pattern already there).
- **Domain-layer message catalog** — RefCounted class (no Node) holding const Dictionary, same pattern as TipCatalog.gd.
- **Session-level dedupe** — in-memory tracking of last-shown condition in GardenScene, cleared between app sessions (not persisted).
- **Boot-emit guard** — WeatherManager always emits weather_changed once on _ready() regardless of actual change (line 76); use `_is_first_weather_signal` flag to skip first emit.
- **Scene positioning** — CanvasLayer anchor 0.5/0.0, offset_top ~150-200px (below VitalityBar 52×72 and RecallBtn 52×52, per project UI memory).

This avoids autoload bloat for a single-scene feature, keeps message catalog purely domain (easy to maintain), and reuses proven Godot patterns from the codebase.

## Dependencies

- Existing: `WeatherManager.gd` (autoload), `WeatherState.gd` (domain enum), `res://assets/npc/eco_npc.png` (sprite asset for TextureButton).
- No external services or new autoloads.

## Risks

- HIGH: Boot-emit emit logic wrong, NPC pops on app startup before reaching GardenScene — **Mitigation:** Gate first emit with `_is_first_weather_signal` flag, tested manually by observing Inspector WeatherManager.mock_condition change on startup.
- MEDIUM: Bubble leaks memory if GardenScene unloads mid-display (Tween still running, node not freed) — **Mitigation:** queue_free on tree_exiting and disconnect from WeatherManager.weather_changed in _exit_tree().
- MEDIUM: Condition enum mismatch if WeatherState.Condition extended in future — **Mitigation:** Message catalog explicitly handles SUNNY, CLOUDY, RAINY, STORM; push_warning() if unknown condition received, plan scope excludes day/night variation and enum extension (P3 out-of-scope).
- LOW: Message pool empty for a condition — **Mitigation:** Populate 2-3 Vietnamese messages per condition during Phase 1; push_error() if get_random_message() receives condition with empty array.

### From plan-reviewer red-team (NOTED, non-blocking)

- NOTED: `_exit_tree()` cleanup should explicitly use `is_instance_valid(_active_weather_bubble)` (not just a null check), matching the `UnlockBanner` precedent at GardenScene.gd lines 245-247 exactly — already reflected in phase-03 step 9.
- NOTED: `_last_shown_condition` uses `-1` as a "nothing shown yet" sentinel outside the `WeatherState.Condition` enum range (0-3). Fragile only if the enum is ever extended, which is explicitly out of scope per spec.md. Keep a comment at the declaration site explaining the sentinel.
- NOTED: The boot-emit guard (`_is_first_weather_signal`) only needs to skip one signal per GardenScene entry, not per app session — this is correct as designed (flag lives on the scene instance, reset every time GardenScene re-enters `_ready()`), but the interaction with session-level dedupe (`_last_shown_condition`, which does NOT reset per entry) is subtle enough to deserve an inline comment in phase-03's implementation.
- NOTED: Spec doesn't require queuing bubbles for rapid successive weather changes (unlike `UnlockBanner`'s `_pending_notifications` queue) — Phase 3's fix is "replace, don't queue" (see step 6). Acceptable for this feature since only the latest weather matters to the player; documented here so it isn't mistaken for an oversight.
- NOTED: Message length isn't hard-capped between Phase 1 and Phase 2. Phase 1 should keep messages ~50-80 characters (already noted in phase-01 risks); Phase 2's bubble Panel should size with enough margin for that length. No enforcement code needed — a spec-level content guideline.
