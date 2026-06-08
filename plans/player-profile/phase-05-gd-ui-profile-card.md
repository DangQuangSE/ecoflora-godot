# Phase 5: Godot UI — UserProfileCard Redesign

## Layer
scenes/hud/ — UserProfileCard.tscn (full redesign) and UserProfileCard.gd (extended logic)

## Files

| File Path | Layer | Change Type |
|-----------|-------|-------------|
| `scenes/hud/UserProfileCard.tscn` | scenes | modify |
| `scenes/hud/UserProfileCard.gd` | scenes | modify |

## Tasks

1. **Redesign the Card panel style in `UserProfileCard.tscn`** to use the farming theme palette:
   - Panel background: dark warm green `Color(0.09, 0.14, 0.06, 0.97)`.
   - Border: 3px solid wood brown `Color(0.52, 0.31, 0.08, 1)`, all four sides.
   - Corner radius: 20px all corners.
   - Panel height: increase `offset_top` from `-320.0` to `-480.0` to accommodate the enlarged layout.

2. **Add avatar display area at the top of the Card** — inside `Card/Content` (VBoxContainer), prepend a `CenterContainer` containing a `Panel` named `AvatarCircle` (size 96x96, circular via corner_radius=48, border 3px wood brown). Inside `AvatarCircle`, add a `TextureRect` named `AvatarImage` (`layout_mode=1`, anchors fill, `expand_mode=1`, `stretch_mode=5`, `mouse_filter=0`). Below the circle, add a `Label` named `UsernameLabel` (centered, font size 16, warm yellow `Color(0.9, 0.85, 0.5, 1)`). Below that, a `Label` named `JoinDateLabel` (centered, font size 11, muted green `Color(0.55, 0.75, 0.45, 0.8)`).

3. **Replace the existing three plain Labels with five stat row nodes** inside `Card/Content`. Each stat row is an `HBoxContainer` with a `TextureRect` icon (16x16, `expand_mode=1`, `stretch_mode=5`) + a `Label` for the name (left, min_size_x=140) and a `Label` for the value (right, expand, right-aligned). Name them:
   - `RowLevel` → icon texture `res://assets/profile/pf_level.png`, name label `"Level"`, value label named `LevelValue`
   - `RowXP` → icon texture `res://assets/profile/pf_exp.png`, name label `"Tổng XP"`, value label named `XPValue`
   - `RowHarvest` → icon texture `res://assets/profile/pf_name.png`, name label `"Thu hoạch"`, value label named `HarvestValue`
   - `RowStreak` → icon texture `res://assets/profile/pf_frame.png`, name label `"Chuỗi đăng nhập"`, value label named `StreakValue`
   - `RowFlowers` → icon texture `res://assets/profile/pf_frame.png`, name label `"Hoa đang có"`, value label named `FlowersValue`
   - Note: reuse existing `assets/profile/` PNGs for icons; artist can swap in dedicated icons later without code changes.
   - All value labels: font size 14, color `Color(0.9, 0.85, 0.5, 1)`.
   - Do NOT use emoji characters in Label text — Android's default Godot font has no emoji glyphs and will render empty boxes.

4. **Add `AvatarPicker` overlay node** as a direct child of `Card` (not inside Content). It is an `HBoxContainer` named `AvatarPicker`, `visible = false`. Set `layout_mode=1`, anchored to bottom of card with a fixed height of 90px, left/right margins 12px. Add 6 child `Button` nodes named `AvatarOpt0` through `AvatarOpt5`, each `flat=true`, containing a `TextureRect` child (64x64, `expand_mode=1`, `stretch_mode=5`). Add a background panel style to `AvatarPicker` (dark overlay `Color(0.04, 0.06, 0.02, 0.95)`, corner_radius 12).

5. **Update `UserProfileCard.gd`** to reference and populate all new nodes:
   - Add `@onready` references for `AvatarImage`, `UsernameLabel`, `JoinDateLabel`, each of the 5 value labels, and `AvatarPicker`.
   - In `open()`: populate all 5 stat values from `UserManager.get_profile()`. Compute `flower_count`:
     ```gdscript
     var count := 0
     for item in InventoryManager.get_inventory():
         if item.category == InventoryItem.Category.HARVEST_PRODUCT \
         and item.harvest_product_id.begins_with("harvest_"):
             count += item.quantity
     FlowersValue.text = str(count)
     ```
     The `begins_with("harvest_")` guard ensures future non-flower harvest items (e.g. `mushroom_spore`) are excluded.
   - Format `join_date`: parse only after confirming the dict is non-empty:
     ```gdscript
     if not p.join_date.is_empty():
         var dt := Time.get_datetime_dict_from_datetime_string(p.join_date, false)
         if not dt.is_empty():
             JoinDateLabel.text = "Tham gia: %02d/%02d/%04d" % [dt["day"], dt["month"], dt["year"]]
     ```
   - Load the avatar texture into `AvatarImage.texture` using the same `load("res://assets/profile/avatars/avatar_%d.png" % idx)` pattern from Phase 4.
   - Connect `AvatarImage`'s parent `Panel` (AvatarCircle) `gui_input` to a handler that toggles `AvatarPicker.visible`.
   - Connect each `AvatarOpt{N}.pressed` signal to a handler that calls `UserManager.set_avatar_async(N)`, hides `AvatarPicker`, and updates `AvatarImage.texture` immediately.
   - Connect `UserManager.profile_updated` in `_ready()` and disconnect in `_exit_tree()`. When fired while visible, re-call the avatar texture update so HUD and card stay in sync.

6. **Preserve the existing slide-up animation and close behavior** — the `open()` tween (`position:y` from 320 to 0 over 0.22s), `close()` tween, and dimmer tap-to-close all remain unchanged. Only the data-population section of `open()` is replaced.

## Acceptance
- Opening the profile card shows: username, join date (or empty if not yet from BE), and correct values for all 5 stat rows.
- `flower_count` matches the sum of `quantity` for all `HARVEST_PRODUCT` items in `InventoryManager` at the time of opening.
- `login_streak` displays the value from `UserManager.get_profile().login_streak`.
- Tapping the avatar circle reveals the `AvatarPicker` overlay with 6 avatar thumbnails.
- Selecting an avatar option: updates `AvatarImage` in the card, closes the picker, and (via `profile_updated` signal) also updates `AvatarTexture` in UserHUD within the same frame.
- Card slide-up animation completes in ≤0.22s with no frame drops.
- `godot --headless --check-only --script res://scenes/hud/UserProfileCard.gd` exits with no errors.
