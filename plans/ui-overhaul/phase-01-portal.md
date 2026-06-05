# Phase 1: Portal Sprite Swap

## Layer
`scenes/`

## Requirements
Portal.tscn renders using the real `portal.png` asset instead of the `demo_portal.png` placeholder, at the same approximate size and position, without affecting collision or any GDScript node reference.

## Files

| File | Node changed | Change description |
|---|---|---|
| `scenes/shared/Portal.tscn` | `Sprite2D` (texture property) | Replace ext_resource `demo_portal.png` → `portal.png` |

## Implementation

**In `scenes/shared/Portal.tscn`:**

1. Remove the existing ext_resource declaration for `demo_portal.png`:
   ```
   [ext_resource type="Texture2D" uid="uid://b6iyvp5pqapb0" path="res://assets/portal/demo_portal.png" id="2_portal"]
   ```
   Replace it with:
   ```
   [ext_resource type="Texture2D" path="res://assets/portal/portal.png" id="2_portal"]
   ```
   - Keep the same `id="2_portal"` so the Sprite2D `texture = ExtResource("2_portal")` line requires no change.
   - Remove the `uid=` field — Godot will regenerate it on next open.

2. No changes needed on the `[node name="Sprite2D"]` block — `texture = ExtResource("2_portal")` stays identical.

3. Verify: the `scale` values (`Vector2(0.21280605, 0.20468083)`) and `position` (`Vector2(17.500004, 19.9)`) remain unchanged. If `portal.png` source resolution differs significantly from `demo_portal.png`, adjust `scale` so the visible sprite still fits within the `RectangleShape2D` size `Vector2(87, 95)`.

**No .gd changes required.** Portal.gd does not reference the texture resource.

## Success Criteria
- Godot opens `Portal.tscn` without "resource not found" errors
- Scene preview shows the new portal sprite rendered at the same screen footprint as before
- CollisionShape2D still visually aligns with the sprite body in the editor
- `godot --headless --check-only --script res://scenes/shared/Portal.gd` exits with no errors

## Risks
- Portal.png source resolution differs from demo_portal.png: adjust `Sprite2D.scale` until sprite fits the 87×95 collision box
