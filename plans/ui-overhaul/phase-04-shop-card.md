# Phase 4: Shop Item Card Texture

## Layer
`scenes/`

## Requirements
Each ShopItemCard renders `shop_card.png` as its panel background instead of the dark StyleBoxFlat placeholder, while VBoxContainer (ItemIcon, NameLabel, PriceLabel) and the TapArea Button remain fully functional.

## Files

| File | Node changed | Change description |
|---|---|---|
| `scenes/shop/ShopItemCard.tscn` | `ShopItemCard` (PanelContainer) | Replace `theme_override_styles/panel` StyleBoxFlat → StyleBoxTexture referencing shop_card.png |

## Implementation

### Step 1 — Add ext_resource for shop_card.png

After the existing `[ext_resource type="Script" ...]` line, add:

```
[ext_resource type="Texture2D" path="res://assets/shop/shop_card.png" id="2_shop_card"]
```

### Step 2 — Replace StyleBoxFlat_card with StyleBoxTexture

Remove the existing sub_resource block:

```
[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_card"]
bg_color = Color(0.1, 0.13, 0.07, 0.92)
corner_radius_top_left = 8
...
border_color = Color(0.4, 0.6, 0.25, 0.7)
```

Add a replacement sub_resource block:

```
[sub_resource type="StyleBoxTexture" id="StyleBoxTexture_card"]
texture = ExtResource("2_shop_card")
draw_center = true
```

- `draw_center = true` ensures the texture body fills the card interior (not just the border slices).
- If `shop_card.png` has defined 9-patch corner regions, add margin properties to this sub_resource:
  ```
  margin_left = {N}
  margin_top = {N}
  margin_right = {N}
  margin_bottom = {N}
  ```
  where N is the pixel size of each corner slice. Measure from the PNG asset. If no 9-patch corners exist, leave all margins at 0 (default).

### Step 3 — Update PanelContainer style reference

In the `[node name="ShopItemCard" type="PanelContainer" ...]` block, change:

```
theme_override_styles/panel = SubResource("StyleBoxFlat_card")
```

to:

```
theme_override_styles/panel = SubResource("StyleBoxTexture_card")
```

All other PanelContainer properties (`custom_minimum_size`, `layout_mode`, `script`) stay unchanged.

### Step 4 — Verify VBoxContainer and TapArea are unaffected

The `VBoxContainer` child and its children (ItemIcon, NameLabel, PriceLabel) have no style overrides referencing StyleBoxFlat_card — they are unaffected. The `TapArea` Button uses `flat = true` with no explicit style — also unaffected. ShopItemCard.gd `setup()` method and the `tapped` signal remain unchanged.

## Success Criteria
- ShopItemCard.tscn opens in Godot without resource errors
- Scene preview shows shop_card.png as the card background
- ItemIcon, NameLabel, and PriceLabel are visible on top of the card texture
- TapArea button fires the `tapped` signal when pressed (no change to interaction)
- Cards instantiated in ShopScene at runtime display the texture (run scene, open shop, confirm cards render correctly)
- `godot --headless --check-only --script res://scenes/shop/ShopItemCard.gd` exits clean

testing: skipped

## Risks
- StyleBoxTexture without 9-patch margins will scale the full PNG uniformly — if shop_card.png has decorative corners, they will stretch on taller cards; mitigation: measure corner margins from the PNG and set margin_* in StyleBoxTexture, or switch the PanelContainer to a NinePatchRect wrapper with VBoxContainer inside if corner integrity is critical
- Two cards per row at 720px width means each card is ~348px wide (with h_separation=8); verify card PNG aspect ratio does not look squished at 110×130 minimum size
