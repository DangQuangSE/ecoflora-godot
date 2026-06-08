# Phase 4: Godot Assets + Input Fix

## Layer
scenes/hud/ (scene file edits + script) and assets/profile/avatars/ (new asset directory)

## Files

| File Path | Layer | Change Type |
|-----------|-------|-------------|
| `assets/profile/avatars/avatar_0.png` | assets | add |
| `assets/profile/avatars/avatar_1.png` | assets | add |
| `assets/profile/avatars/avatar_2.png` | assets | add |
| `assets/profile/avatars/avatar_3.png` | assets | add |
| `assets/profile/avatars/avatar_4.png` | assets | add |
| `assets/profile/avatars/avatar_5.png` | assets | add |
| `scenes/hud/UserHUD.tscn` | scenes | modify |
| `scenes/hud/UserHUD.gd` | scenes | modify |

## Tasks

1. **Create directory `assets/profile/avatars/`** and add 6 placeholder PNG files named `avatar_0.png` through `avatar_5.png`. Each file must be exactly 128x128px PNG format, max 100KB. Placeholders should be solid-color filled circles on a transparent background — one per avatar slot. Suggested colors: avatar_0=warm green (#5A9E4A), avatar_1=sky blue (#5A9EDB), avatar_2=soft pink (#E87D9E), avatar_3=golden yellow (#E8C45A), avatar_4=lavender (#9E7DE8), avatar_5=coral (#E87D5A). The developer will replace these with real art; the filenames must not change.

2. **Remove the `_gui_input` override from `UserHUD.gd`** — delete the entire `func _gui_input(event: InputEvent) -> void` block. This is the root cause of the CoinButton input-blocking bug: the panel consumed all taps before CoinButton could receive them.
   After removing `_gui_input`, set `UserHUD`'s root Control node `mouse_filter = 0` (MOUSE_FILTER_STOP) in `UserHUD.tscn` to prevent taps on the HUD background from falling through to the garden/plot layer beneath. Without this, any tap on HUD whitespace that neither ProfileButton nor CoinButton covers would trigger plot interactions.

3. **Add an invisible `Button` node named `ProfileButton` to `UserHUD.tscn`** covering the avatar + name area. The button must sit above AvatarRect and NameLabel in the node tree (add after CoinButton in the scene). Offsets: `offset_left = 32.0, offset_top = 30.0, offset_right = 284.0, offset_bottom = 100.0` (covers AvatarRect at 32.5–98.5 and NameLabel at 124.75–284.75 in the horizontal span). Set `flat = true` and `mouse_filter = 0` so it captures input without drawing. Set `focus_mode = 0` (no keyboard focus on mobile).

4. **Add `TextureRect` node named `AvatarTexture` as a child of `AvatarRect` in `UserHUD.tscn`**. Set `layout_mode = 1`, `anchor_right = 1.0`, `anchor_bottom = 1.0` (fills parent), `expand_mode = 1` (fit), `stretch_mode = 5` (keep aspect centered), `mouse_filter = 2` (ignore — ProfileButton above handles input).

5. **Update `UserHUD.gd`** to wire the new nodes:
   - Add `@onready var _profile_btn: Button = $ProfileButton` and `@onready var _avatar_texture: TextureRect = $AvatarRect/AvatarTexture`.
   - In `_ready()`: connect `_profile_btn.pressed.connect(_open_profile_card)` and `UserManager.profile_updated.connect(_on_profile_updated)`.
   - Add `func _on_profile_updated() -> void` that calls `_refresh_avatar()`.
   - Add `func _refresh_avatar() -> void` that loads `"res://assets/profile/avatars/avatar_%d.png" % UserManager.get_profile().avatar_index` with `load()`, assigns it to `_avatar_texture.texture`. Guard with `ResourceLoader.exists(path)` before loading.
   - Call `_refresh_avatar()` at the end of the existing `_ready()`.
   - In `_exit_tree()`: disconnect `UserManager.profile_updated`.

6. **Verify CoinButton is unaffected** — `CoinButton` is positioned at offsets 21–207 / 123–152, well below the ProfileButton region (30–100 vertical). No z-index changes needed; Godot processes Button nodes by tree order, so ProfileButton above CoinButton in the tree is correct.

## Acceptance
- Tapping the avatar/name area in the HUD opens UserProfileCard in under 0.3s.
- Tapping the coin area still opens the shop (CoinButton.pressed fires, _open_profile_card does not).
- `_avatar_texture.texture` reflects the current `avatar_index` immediately after `_ready()`.
- After calling `UserManager.set_avatar_async(2)`, `_avatar_texture.texture` updates within the same frame (no await needed — `profile_updated` signal is synchronous).
- `ResourceLoader.exists("res://assets/profile/avatars/avatar_0.png")` returns true.
- `godot --headless --check-only --script res://scenes/hud/UserHUD.gd` exits with no errors.
