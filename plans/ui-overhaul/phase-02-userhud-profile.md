# Phase 2: UserHUD Profile Assets

## Layer
`scenes/`

## Requirements
UserHUD displays the three profile PNG assets — `pf_frame.PNG` as the avatar frame overlay, `pf_name.PNG` as the name/level strip background, and `pf_exp.PNG` as the XP bar visual background — while all existing GDScript signal wiring ($LevelLabel, $XPBar, $CoinLabel) continues to resolve correctly.

## Files

| File | Node changed | Change description |
|---|---|---|
| `scenes/hud/UserHUD.tscn` | `AvatarRect` | Change type `ColorRect` → `TextureRect`; set texture to `pf_frame.PNG`; set stretch_mode to KEEP_ASPECT_CENTERED |
| `scenes/hud/UserHUD.tscn` | `NameBg` (new node) | Add `TextureRect` as first child of root Panel, positioned behind `LevelLabel`; texture = `pf_name.PNG` |
| `scenes/hud/UserHUD.tscn` | `XPBar` | Replace `theme_override_styles/background` StyleBoxFlat with a StyleBoxTexture referencing `pf_exp.PNG` |
| `scenes/hud/UserHUD.gd` | line 6 `_avatar` | Update type annotation `ColorRect` → `TextureRect` to match the node class change |

## Implementation

### Step 1 — Add ext_resources for the three PNG assets

At the top of `UserHUD.tscn`, after the existing `[ext_resource type="Script" ...]` line, add:

```
[ext_resource type="Texture2D" path="res://assets/profile/pf_frame.PNG" id="2_pf_frame"]
[ext_resource type="Texture2D" path="res://assets/profile/pf_name.PNG" id="3_pf_name"]
[ext_resource type="Texture2D" path="res://assets/profile/pf_exp.PNG" id="4_pf_exp"]
```

### Step 2 — Add StyleBoxTexture sub_resource for XPBar background

Add a new sub_resource block (before the `[node ...]` sections):

```
[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_xpbg"]
texture = ExtResource("4_pf_exp")
```

Remove the existing `[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_xpbg"]` block (it is only used by XPBar background; the fill StyleBoxFlat stays).

### Step 3 — Change AvatarRect from ColorRect to TextureRect

Replace the existing `[node name="AvatarRect" type="ColorRect" ...]` block with:

```
[node name="AvatarRect" type="TextureRect" parent="."]
layout_mode = 0
offset_left = 8.0
offset_top = 8.0
offset_right = 56.0
offset_bottom = 56.0
mouse_filter = 2
texture = ExtResource("2_pf_frame")
expand_mode = 1
stretch_mode = 5
```

- Remove the `color` and `theme_override_styles/panel` properties (ColorRect-specific).
- `stretch_mode = 5` is KEEP_ASPECT_CENTERED; use `stretch_mode = 3` (SCALE) if the frame must fill exactly.
- The `StyleBoxFlat_avatar` sub_resource is no longer referenced — remove its block.

### Step 4 — Add NameBg TextureRect behind LevelLabel

Insert a new node block immediately before the `[node name="LevelLabel" ...]` block:

```
[node name="NameBg" type="TextureRect" parent="."]
layout_mode = 0
offset_left = 60.0
offset_top = 6.0
offset_right = 164.0
offset_bottom = 34.0
mouse_filter = 2
texture = ExtResource("3_pf_name")
expand_mode = 1
stretch_mode = 3
```

Adjust offsets to cover the LevelLabel area (64–160 x, 8–32 y) with 2–4 px padding on each side. In the Godot editor, reorder NameBg to be below LevelLabel in the scene tree if needed so the label renders on top (Godot renders children in order; NameBg declared first = drawn first = behind LevelLabel).

### Step 5 — Update XPBar background style reference

In the `[node name="XPBar" ...]` block, change:

```
theme_override_styles/background = SubResource("StyleBoxFlat_xpbg")
```

to:

```
theme_override_styles/background = SubResource("StyleBoxTexture_xpbg")
```

All other XPBar properties (`max_value`, `value`, `show_percentage`, fill style) remain unchanged.

### Step 6 — Update UserHUD.gd type annotation

In `scenes/hud/UserHUD.gd` line 6, change:

```gdscript
@onready var _avatar: ColorRect    = $AvatarRect
```

to:

```gdscript
@onready var _avatar: TextureRect  = $AvatarRect
```

This is the only .gd change. All other `@onready` paths and signal connections are unaffected. The `_play_level_up_anim` tween on `_avatar.modulate` works identically on TextureRect.

## Success Criteria
- `UserHUD.tscn` opens in Godot with no missing-resource errors
- AvatarRect node type is TextureRect and shows pf_frame.PNG in scene preview
- NameBg TextureRect is visible behind LevelLabel text
- XPBar background shows pf_exp.PNG texture instead of the dark flat colour
- `godot --headless --check-only --script res://scenes/hud/UserHUD.gd` exits clean
- UserManager signals (xp_gained, level_up, currency_changed) still update LevelLabel, XPBar, CoinLabel at runtime

## Risks
- `_avatar` tween in `_play_level_up_anim` uses `modulate` property — available on all CanvasItem subclasses including TextureRect; no breakage
- pf_frame.PNG described as transparent-center overlay — if it has opaque fill, avatar artwork will be hidden; inspect asset and set `expand_mode = 0` (KEEP_SIZE) if needed
