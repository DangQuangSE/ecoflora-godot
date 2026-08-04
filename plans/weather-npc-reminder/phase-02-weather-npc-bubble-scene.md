# Phase 2: WeatherNpcBubble Scene & Script

## Requirements

This phase delivers a reusable CanvasLayer scene (WeatherNpcBubble.tscn + WeatherNpcBubble.gd) displaying the eco_npc sprite as a TextureButton and a speech bubble containing a localized message. The bubble auto-hides via Tween fade-out (modulate:a) after a configurable duration (@export auto_hide_seconds) or instantly on tap-to-dismiss. The scene is positioned below existing HUD elements (VitalityBar, RecallBtn) to avoid overlap, follows FloatLabel.gd's Tween pattern, and cleans up via queue_free.

## Steps

1. Create `scenes/garden/WeatherNpcBubble.tscn` as CanvasLayer with anchor_left=0.5, anchor_top=0.0, offset_top=170px as the .tscn default (fits the gap between HUD's UserHUD/SettingsButton at top and LeftIconGrid/RightIconGrid starting further down — see `scenes/hud/HUD.tscn`). Centered horizontally (offset_left=0, width=0 or auto). Mirror this default into `@export var vertical_offset: float = 170.0` and `@export var horizontal_offset: float = 0.0` on the root Control/CanvasLayer's positioning child (e.g. a top-level Control holding NpcButton + BubblePanel) so the position is tunable from the Inspector without editing the .tscn or script — apply these in `_ready()` via `position = Vector2(horizontal_offset, vertical_offset)` on that container node.

2. Add child TextureButton node (name: NpcButton) with texture_normal set to `res://assets/npc/eco_npc.png`, custom_minimum_size ~64×64, disable focus/modulate_ignore_parent as needed.

3. Add child Control or Panel node (name: BubblePanel) as sibling or parent of label, positioned near NPC with light background color (e.g., white/light green semi-transparent), containing a Label (name: MessageLabel) with text wrapping enabled, font size tuned for readability (~14-18pt), color dark or on-theme.

4. Implement `scenes/garden/WeatherNpcBubble.gd` script: accept message String in function `show_message(msg: String) -> void`; connect NpcButton.pressed signal to `_on_button_pressed()` private function.

5. Implement auto-hide via Tween: in `show_message()`, wait `auto_hide_seconds` (e.g. `get_tree().create_timer(auto_hide_seconds).timeout`), then create a tween that fades modulate:a from 1.0 to 0.0, `await tween.finished` (mirror `FloatLabel.gd` line 19-20 exactly — never `queue_free()` while a tween on this node is still running), then `queue_free()`. Store the tween in `_active_tween: Tween` so it can be killed elsewhere.

6. Implement tap-to-dismiss: in `_on_button_pressed()`, if `_active_tween != null and _active_tween.is_valid()`, call `_active_tween.kill()` first, then `queue_free()` immediately (no fade needed on manual dismiss); emit optional signal `dismissed` if parent wants to track.

7. Handle cleanup on tree_exiting: connect `tree_exiting` to a handler that kills `_active_tween` if valid (`_active_tween.kill()`) before the node is freed, preventing "tween running on freed node" errors when the parent scene (GardenScene) unloads mid-display. Disconnect any signals if connected.

## Success Criteria

- Scene file `scenes/garden/WeatherNpcBubble.tscn` exists with CanvasLayer root, TextureButton for eco_npc, and Label for message.
- Script `scenes/garden/WeatherNpcBubble.gd` callable with `show_message(msg: String)` function.
- @export var `auto_hide_seconds: float = 5.0` editable in Inspector.
- @export var `vertical_offset: float = 170.0` and `@export var horizontal_offset: float = 0.0` editable in Inspector, repositioning the whole NPC+bubble group without touching code or the .tscn.
- Bubble displays correctly on-screen at specified offset, eco_npc sprite visible and clickable (TextureButton.pressed fires on tap).
- Tapping eco_npc or bubble (if Control extends over message area) dismisses immediately; bubble fades out after auto_hide_seconds if not tapped.
- Modulate:a fades from 1.0 to 0.0 smoothly (Tween.TRANS_FADE or similar, 0.5-1.0s fade duration, @export if configurable).
- No memory leaks: queue_free called on dismiss (auto or manual); no orphaned tweens or signals; tree_exiting or _exit_tree cleanup in place.
- Manual verification: in-editor, instantiate scene, call `show_message("Test message")`, observe fade-out after 5 seconds and instant dismiss on click.

## Risks

- TextureButton input event hijacked by parent Control or Area2D — **Mitigation:** Set mouse_filter = MOUSE_FILTER_STOP on TextureButton, ensure CanvasLayer is not blocked by other UI; test with WeatherNpc visible alongside HUD in Phase 3.
- Tween running after queue_free causes error — **Mitigation:** auto-hide path uses `await tween.finished` before `queue_free()` (never free while tween active); manual dismiss and `tree_exiting` both call `_active_tween.kill()` first (see Steps 5-7).
- Message text overflow or font too small — **Mitigation:** Use @export custom_minimum_size for Panel, adjust Label font size and wrap in Inspector, test with Phase 1 sample messages (50-80 char Vietnamese strings).
- Modulate fade doesn't work if parent opacity is 0 — **Mitigation:** Ensure CanvasLayer modulate is 1.0 at start; verify in _ready() and apply modulate.a = 1.0 explicitly before tween starts.
