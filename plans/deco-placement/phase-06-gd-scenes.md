# Phase 6: GD Scenes Integration

## Layer
scenes/ (Godot 4 — GDScript + .tscn, top of Clean Architecture Godot stack)

## Requirements
Wire `DecoManager` into GardenScene and SchoolScene, build `DecoNode` as the interactive per-placement node, and add the Edit Mode toggle and Save button to the HUD — delivering the complete player-facing placement, drag, and recall experience.

## Files

| File | Action | Layer | Purpose |
|------|--------|-------|---------|
| `scenes/shared/DecoNode.tscn` | Create | scenes/ | Scene tree: Sprite2D root → Area2D → CollisionShape2D (RectangleShape2D) |
| `scenes/shared/DecoNode.gd` | Create | scenes/ | Holds placement_id, handles tap (recall) and drag (edit mode), emits tapped + drag_ended |
| `scenes/garden/GardenScene.tscn` | Modify | scenes/ | Add DecoLayer (Node2D, z_index=3) as child of scene root |
| `scenes/garden/GardenScene.gd` | Modify | scenes/ | init_scene call in _ready, connect placements_loaded, spawn/remove DecoNodes |
| `scenes/school/SchoolScene.tscn` | Modify if bg exists | scenes/ | Add DecoLayer only if scene has a background Sprite2D node |
| `scenes/school/SchoolScene.gd` | Modify if bg exists | scenes/ | Same pattern as GardenScene.gd — skip entirely if no background node |
| `scenes/shared/UserHUD.tscn` | Modify | scenes/ | Add EditModeButton (ToggleButton) and SaveButton (hidden outside edit mode) |
| `scenes/shared/UserHUD.gd` | Modify | scenes/ | Connect edit_mode_changed signal, show/hide SaveButton, call batch_move_async on Save |

## Steps
1. Create `scenes/shared/DecoNode.tscn` with the node tree: `Sprite2D` (root, script attached) → `Area2D` → `CollisionShape2D` using `RectangleShape2D`. Set `z_index = 0` on the node itself (DecoLayer's z_index=3 handles elevation). Export a `placement_data: DecoPlacement` property so the spawning scene can inject the full placement object after instancing.
2. Implement `DecoNode.gd` on the `Sprite2D` root. Signals: `tapped(placement_id: String)`, `drag_ended(placement_id: String, new_pos: Vector2)`. In `_ready`, resolve texture via `ItemIconRegistry.get_icon(placement_data.decor_slug)` — `decor_slug` is `decor.Name.to_lower().replace(" ", "_")` already computed by the backend. Set `CollisionShape2D` extents to match the loaded texture size.
3. Implement touch input in `DecoNode.gd` using `_input_event(viewport, event, shape_idx)` on the `Area2D`. Track touch start position and timestamp. On `InputEventScreenDrag`: if `DecoManager.edit_mode` is true, move the node and clamp to the boundary rect passed in from the parent scene. On `InputEventScreenTouch` release: if total drag distance < 12px AND elapsed < 300ms → emit `tapped(placement_data.id)`. If drag threshold exceeded in edit mode → emit `drag_ended(placement_data.id, position)`.
4. In any scene that opts into deco placement, add to `_ready`: check `has_node("Background")` (or equivalent background node name) — if no background node exists, skip deco init entirely (no `DecoLayer`, no `DecoManager.init_scene` call). If background exists, call `await DecoManager.init_scene(scene_name)` where `scene_name` is a string constant defined per scene (`"garden"`, `"school"`, or whatever the scene calls itself). Connect `DecoManager.placements_loaded`, `deco_placed`, `deco_recalled` signals.
5. Implement `_on_placements_loaded`: clear all existing children of `DecoLayer`, then for each `DecoPlacement` in the array, instance `DecoNode.tscn`, set `placement_data`, set `position = Vector2(p.position_x, p.position_y)`, connect its `tapped` and `drag_ended` signals, and add as child of `DecoLayer`. Compute the boundary rect from the background `Sprite2D` once and store it for clamping.
6. Implement `_on_deco_placed`: instance a new `DecoNode`, inject placement data, add to `DecoLayer`. Implement `_on_deco_recalled`: find the child `DecoNode` whose `placement_data.id` matches, queue_free it. For the optimistic temp-id swap (Phase 5 risk), find the DecoNode by temp id and update its `placement_data.id` to the server-confirmed id instead of replacing the node.
7. Add `EditModeButton` (CheckButton or Button with toggle mode) and `SaveButton` to `UserHUD.tscn`, both default `visible = false`. In `UserHUD.gd`, connect `DecoManager.scene_deco_ready(enabled: bool)` signal: show/hide `EditModeButton` based on `enabled` — this signal is emitted by `DecoManager.init_scene` on success (`true`) and can be emitted `false` when a non-deco scene loads. This way login and any scene without a background node never show the Edit button. On `EditModeButton` pressed, call `DecoManager.set_edit_mode(not DecoManager.edit_mode)`. Connect `DecoManager.edit_mode_changed` to show/hide `SaveButton`. On `SaveButton` pressed, collect all `DecoNode` positions from `DecoLayer` and call `DecoManager.batch_move_async(moves)`. Connect `DecoManager.batch_save_failed` to restore node positions.
8. On `DecoNode.tapped` in the scene handler: if NOT in edit mode, show a `ConfirmationDialog` ("Recall this decoration?"). On confirmed, call `DecoManager.recall_deco_async(placement_id)`. In edit mode, tapping does nothing (drag only).

## Spec Coverage
- P1 (all four stories): placement persists, edit mode drag + save, recall, decos visible on re-entry
- P2: z_index=3 on DecoLayer ensures newer decos (added later as children) render on top within the layer
- FR-07: DecoLayer as Node2D z_index=3, DecoNodes spawned from `placements_loaded`
- FR-08: Edit Mode toggle in HUD, inventory panel hidden in edit mode, tap-to-recall with confirm dialog outside edit mode
- FR-09: Boundary clamping from background Sprite2D rect in DecoNode drag handler
- FR-10: Texture loaded via `ItemIconRegistry` or `decor_image_url` on each `DecoNode`

## Done When
- Launch GardenScene: all placements from MockDecoService appear at correct positions within the scene (visible, not off-screen)
- Tap a placed DecoNode (outside edit mode): ConfirmationDialog appears; confirm → node disappears, `DecoManager.deco_recalled` fires
- Press EditModeButton: SaveButton appears, inventory panel hides, `edit_mode_changed(true)` confirmed via print/signal watcher
- In edit mode, drag a DecoNode to a new position: node moves, stays within background boundary, does not fire recall
- Press Save: `batch_move_async` is called (visible in MockDecoService log); `batch_saved` fires; SaveButton returns to normal state
- Reload GardenScene: decos reappear (mock service returns same positions since mock data is static — acceptable for this phase)
- SchoolScene passes all the same checks with `"school"` as scene name
- `godot --headless --check-only` on all four modified .gd files exits with zero errors

## Risks
- **`_input_event` vs `_unhandled_input`:** `Area2D._input_event` only fires when the touch hits the collision shape. If two DecoNodes overlap, both fire. Add an `accept_event()` call in the top-most node's handler and rely on z_index order. Test with two overlapping decos.
- **Boundary rect at runtime:** If the background Sprite2D is centered and uses a non-zero offset, the boundary rect must be computed as `global_position + (-texture_size/2)` to `global_position + (texture_size/2)`. Hardcoding the rect will break on different screen sizes.
- **DecoLayer z_index vs HUD CanvasLayer:** HUD is a `CanvasLayer` (layer >= 1) which always renders above all Node2D z_indexes. Confirm `z_index=3` on DecoLayer is above plot nodes (expected z_index=1 or 2) but that the HUD remains untouchable by DecoNode hit detection (CanvasLayer input is separate).
- **Optimistic temp-id node swap:** If the server returns the confirmed placement before the next frame, swapping the id on the existing node is straightforward. If there is a multi-frame delay, the node may receive a `deco_recalled` for the temp id before the swap completes. Coordinate signal order with Phase 5 implementation.
- **SaveButton collects positions from DecoLayer children:** If a DecoNode was recalled (queue_freed) between entering edit mode and pressing Save, its ghost entry must not appear in the moves array. Using `get_children()` at Save time (after free) is safe — freed nodes are removed from the children list.
