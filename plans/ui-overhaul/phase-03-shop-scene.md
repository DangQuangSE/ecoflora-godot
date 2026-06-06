# Phase 3: Shop Scene Background and Tab Styling

## Layer
`scenes/`

## Requirements
ShopScene renders `shop_bg.PNG` as a fullscreen portrait background, and the TabContainer tabs display `shop_tab.png` (unselected) / `shop_tab_clicked.png` (selected) instead of the engine-default flat style. All ShopScene.gd node references ($BackButton, $TabContainer, $LoadingSpinner, $ConfirmDialog and children) remain intact.

## Files

| File | Node changed | Change description |
|---|---|---|
| `scenes/shop/ShopScene.tscn` | `BgTexture` (new node) | Add TextureRect as first child of root Control; anchors full-screen; texture = shop_bg.PNG |
| `scenes/shop/ShopScene.tscn` | `TabContainer` | Add theme_override StyleBoxTexture for tab_unselected and tab_selected styles |

## Implementation

### Step 1 — Add ext_resources for shop assets

After the existing `[ext_resource type="Script" ...]` line, add:

```
[ext_resource type="Texture2D" path="res://assets/shop/shop_bg.PNG" id="2_shop_bg"]
[ext_resource type="Texture2D" path="res://assets/shop/shop_tab.png" id="3_shop_tab"]
[ext_resource type="Texture2D" path="res://assets/shop/shop_tab_clicked.png" id="4_shop_tab_clicked"]
```

### Step 2 — Add StyleBoxTexture sub_resources for tab styles

Add two sub_resource blocks before the `[node ...]` sections:

```
[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_tab_unsel"]
texture = ExtResource("3_shop_tab")

[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_tab_sel"]
texture = ExtResource("4_shop_tab_clicked")
```

### Step 3 — Add BgTexture as first child of root Control

Insert a new node block immediately after the `[node name="ShopScene" ...]` root node block and before the `[node name="BackButton" ...]` block:

```
[node name="BgTexture" type="TextureRect" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 0.0
offset_top = 0.0
offset_right = 0.0
offset_bottom = 0.0
mouse_filter = 2
texture = ExtResource("2_shop_bg")
expand_mode = 1
stretch_mode = 3
```

- `anchors_preset = 15` fills the full parent (720×1280).
- `stretch_mode = 3` = SCALE — stretches to fill exactly; change to `stretch_mode = 6` (KEEP_ASPECT_COVERED) if the design requires letterbox-safe scaling.
- `mouse_filter = 2` = IGNORE — background never blocks taps on BackButton or TabContainer.
- Node declared before BackButton in the file → rendered first → behind all other nodes. No z_index manipulation needed.

### Step 4 — Apply tab StyleBoxTexture overrides to TabContainer

In the `[node name="TabContainer" ...]` block, add these two lines after the existing `theme_override_font_sizes/font_size` line:

```
theme_override_styles/tab_unselected = SubResource("StyleBoxTexture_tab_unsel")
theme_override_styles/tab_selected = SubResource("StyleBoxTexture_tab_sel")
```

No other TabContainer properties change. The `tab_changed` signal connection in ShopScene.gd is unaffected by theme overrides.

### Step 5 — Remove or keep StyleBoxFlat_bg

The root ShopScene node uses `theme_override_styles/panel = SubResource("StyleBoxFlat_bg")`. Because BgTexture now covers the background, this flat panel style will be hidden behind it. Leave it in place (Panel fallback if texture fails to load) or remove it — either is safe. Recommended: leave it as a fallback.

## Success Criteria
- ShopScene.tscn opens in Godot without errors
- Scene preview shows shop_bg.PNG filling the 720×1280 area behind all other nodes
- TabContainer tabs render shop_tab.png for unselected and shop_tab_clicked.png for the active tab
- BgTexture does not intercept any touch events (mouse_filter = IGNORE)
- `_tab_container.tab_changed` signal still fires when switching tabs (verified by running the scene and tapping each tab)
- All `@onready` paths in ShopScene.gd resolve: BackButton, TabContainer, LoadingSpinner, ConfirmDialog

testing: skipped

## Risks
- BgTexture declared after root node but before BackButton in file order: if a future editor drag-and-drop reorders the tree, BgTexture could end up above UI nodes visually — mitigation: lock BgTexture node in editor after wiring
- Tab StyleBoxTexture may need content_margin_* set if tab labels are clipped by the PNG frame edges — mitigation: check in editor preview and add `content_margin_left/right/top/bottom` to the sub_resource blocks if needed
