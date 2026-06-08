# Phase 5: GD DecoManager Autoload

## Layer
autoloads/ (Godot 4 — GDScript, registered singleton)

## Requirements
Deliver `DecoManager.gd` as the single source of truth for deco state in Godot: it owns the `edit_mode` flag, the live placement list per scene, and the four async operations (init, place, batch-move, recall) — each following the optimistic UI pattern from CLAUDE.md.

## Files

| File | Action | Layer | Purpose |
|------|--------|-------|---------|
| `autoloads/DecoManager.gd` | Create | autoloads/ | Singleton: signals, edit_mode, init_scene, place, batch_move, recall with optimistic UI |
| `project.godot` | Modify | — | Register DecoManager autoload after WeatherManager |

## Steps
1. Create `autoloads/DecoManager.gd` with `class_name DecoManager extends Node`. Declare all signals at the top before any variable: `placements_loaded(placements: Array)`, `deco_placed(placement: DecoPlacement)`, `deco_recalled(placement_id: String)`, `batch_saved`, `batch_save_failed`, `edit_mode_changed(is_edit: bool)`, `scene_deco_ready(enabled: bool)`. `scene_deco_ready(true)` is emitted after `init_scene` succeeds; `scene_deco_ready(false)` must be called by any scene that does NOT have a background node in its `_ready` — HUD connects to this to show/hide the Edit Mode button. Add typed properties: `edit_mode: bool = false`, `current_scene_name: String = ""`, `_placements: Array = []`, `_pending_sync: bool = false`.
2. Implement `set_edit_mode(value: bool) -> void`: set `edit_mode = value`, emit `edit_mode_changed(value)`. Scenes and HUD connect to this signal to show/hide drag handles and the Save button.
3. Implement `init_scene(scene_name: String) -> void`: set `current_scene_name`, call `await _service.get_placements_async(scene_name)`, store the result in `_placements`, emit `placements_loaded(_placements)`. Guard with `await get_tree().process_frame` before emitting to ensure the scene tree is ready for child node creation.
4. Implement `place_deco_async(inventory_item_id: String, scene_name: String, x: float, y: float) -> void` with the optimistic UI pattern: (a) immediately create a local `DecoPlacement` with a temporary id and emit `deco_placed`; (b) await `_service.place_deco_async(...)`; (c) on success, replace the temporary local entry with the server-confirmed one and emit `deco_placed` again with the real id; (d) on failure, emit `deco_recalled(temp_id)` to remove the optimistic node and show an error.
5. Implement `recall_deco_async(placement_id: String) -> void` with the optimistic UI pattern: (a) find and remove the placement from `_placements`, emit `deco_recalled(placement_id)` immediately; (b) await `_service.recall_deco_async(placement_id)`; (c) on failure, re-add the placement to `_placements` and emit `deco_placed` to restore the node.
6. Implement `batch_move_async(moves: Array) -> void`: before any optimistic update, **snapshot the pre-move positions** from `_placements` into a local `_pre_move_snapshot: Dictionary` keyed by placement id. Apply new positions to `_placements` optimistically. Await `_service.batch_move_async(moves)`. On success, emit `batch_saved`. On failure, **restore `_placements` from `_pre_move_snapshot`** and emit `batch_save_failed` — scenes connect to `batch_save_failed` to reposition `DecoNode` instances back to their snapshot coordinates via `deco_node.position = Vector2(snap.x, snap.y)`.
7. Add `_pending_sync: bool = false` guard to `place_deco_async` and `recall_deco_async`. Emit a new signal `sync_state_changed(is_busy: bool)` when `_pending_sync` changes. Phase 6's inventory panel **must** connect to this signal and disable the "place deco" trigger while `is_busy == true`, re-enabling only after the async completes (success or rollback). This prevents double-tap race conditions with the temp-id optimistic node.
8. Wire the service: in `_ready`, instantiate `MockDecoService` (for development) or `RealDecoService` (for production) into a `_service` variable. Follow the same pattern used by other autoloads (e.g., a flag constant or project setting to switch between mock and real).
8. Register `DecoManager` in `project.godot` autoloads list immediately after `WeatherManager`, ensuring it loads last. Key: `DecoManager`, path: `res://autoloads/DecoManager.gd`.

## Spec Coverage
- FR-06: DecoManager autoload registered after WeatherManager (spec says FocusManager; WeatherManager is the current last autoload)
- FR-08 (partial): `edit_mode` state owned by DecoManager, toggle propagated via signal
- FR-02, FR-03, FR-04, FR-05: All four operations delegated through the service layer with optimistic UI
- CLAUDE.md optimistic UI pattern: `_pending_sync` guard, local predict → async sync → rollback on failure

## Done When
- `godot --headless --check-only --script res://autoloads/DecoManager.gd` exits with zero errors
- `project.godot` lists `DecoManager` in the autoload section after `WeatherManager`
- In a test scene that calls `DecoManager.init_scene("garden")`, `placements_loaded` fires with an Array containing the mock placements
- Calling `DecoManager.set_edit_mode(true)` emits `edit_mode_changed(true)`
- Calling `DecoManager.recall_deco_async("fake-id")` with MockDecoService: `deco_recalled` fires immediately (optimistic), then the mock success path completes without error

## Risks
- **`await get_tree().process_frame` timing:** If `init_scene` is called from a scene's `_ready` before the scene is added to the tree, `get_tree()` may not be available on `DecoManager` itself. Use `await get_tree().process_frame` inside `DecoManager` only if `DecoManager` is already in the tree (as an autoload it always is). The guard is safe.
- **Optimistic place with temporary id:** The temporary placement node uses a fake id (e.g., a `UUID()` helper or a timestamp string). When the server response replaces it, the scene must swap the id on the existing `DecoNode` rather than destroy-and-recreate it to avoid visual flicker. Communicate this constraint to Phase 6 implementors.
- **Concurrent operations:** `_pending_sync` guards individual place/recall calls, but a user could quickly place two decos. Each call needs its own guard flag, or use a counter. Simplest solution: disable the "place from inventory" button while any `_pending_sync` is true.
