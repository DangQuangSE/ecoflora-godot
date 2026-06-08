# Phase 4: GD Domain & Services

## Layer
domain/ + services/ (Godot 4 — GDScript, Clean Architecture Godot layers)

## Requirements
Create the `DecoPlacement` domain class and the full service stack (interface, mock, real) so `DecoManager` in Phase 5 can fetch, place, batch-move, and recall placements without importing any Node or autoload.

## Files

| File | Action | Layer | Purpose |
|------|--------|-------|---------|
| `domain/DecoPlacement.gd` | Create | domain/ | RefCounted data class: id, inventory_item_id, decor_id, decor_image_url, scene_name, position_x, position_y |
| `services/DecoService.gd` | Create | services/ | Abstract interface: from_dict, get_placements_async, place_deco_async, batch_move_async, recall_deco_async |
| `services/MockDecoService.gd` | Create | services/ | Returns hardcoded test placements for offline development |
| `services/RealDecoService.gd` | Create | services/ | Calls backend endpoints with JWT auth header, parses ApiResponse envelope |

## Steps
1. Create `domain/DecoPlacement.gd` as a `class_name DecoPlacement extends RefCounted`. Define eight typed properties: `id: String`, `inventory_item_id: String`, `decor_id: String`, `decor_slug: String`, `decor_image_url: String`, `scene_name: String`, `position_x: float`, `position_y: float`. Add `decor_slug` specifically because `ItemIconRegistry` is keyed by slug strings (e.g., `"rock"`, `"water_tower"`), **not** by HTTP URLs — `decor_image_url` alone cannot resolve to a local texture. The backend `DecoPlacementDto` must also include this field. Add a static `from_dict(d: Dictionary) -> DecoPlacement` factory. No Node, no autoload import, no signal.
2. Create `services/DecoService.gd` as an abstract base (or documented interface) with five method stubs: `from_dict`, `get_placements_async(scene_name: String) -> Array[DecoPlacement]`, `place_deco_async(inventory_item_id: String, scene_name: String, x: float, y: float) -> DecoPlacement`, `batch_move_async(moves: Array) -> bool`, `recall_deco_async(placement_id: String) -> bool`. Follow the same interface pattern used by existing services in the project.
3. Create `services/MockDecoService.gd` extending `DecoService`. In `get_placements_async`, return a hardcoded `Array[DecoPlacement]` of 2–3 test entries with realistic x/y values within the garden background rect. Set `decor_slug` to a slug key that is **already registered in `ItemIconRegistry`** (check `autoloads/ItemIconRegistry.gd` for valid keys — e.g., `"rock"`). Do not use an HTTP URL as `decor_slug` or the texture lookup will always miss. All other methods return success values immediately with no await.
4. Create `services/RealDecoService.gd` extending `DecoService`. Each method builds the correct HTTP request (URL, method, headers with `Authorization: Bearer {token}`) using the project's existing HTTP helper, awaits the response, unwraps the `ApiResponse<T>` envelope, and returns a typed result or null/false on error. Use `push_error()` for non-2xx responses — no `print()`.
5. In `RealDecoService`, confirm the JWT token is retrieved from the same source as other real services in the project (e.g., a stored token in `UserManager` or a shared auth helper). Do not import `UserManager` directly — pass the token in or read from a shared constant path matching the project pattern.

## Spec Coverage
- FR-06 (partial): Service layer that `DecoManager` will wrap
- FR-10: `decor_image_url` carried on `DecoPlacement` domain object so `DecoNode` can use `ItemIconRegistry` or direct URL
- NFR Security: JWT auth header on every RealDecoService call

## Done When
- `godot --headless --check-only --script res://domain/DecoPlacement.gd` exits with zero errors
- `godot --headless --check-only --script res://services/MockDecoService.gd` exits with zero errors
- `godot --headless --check-only --script res://services/RealDecoService.gd` exits with zero errors
- `MockDecoService.get_placements_async("garden")` returns an Array of at least 2 `DecoPlacement` objects with all seven fields populated (verifiable by printing field values in a test script)
- `DecoPlacement.from_dict({"id":"abc","inventory_item_id":"xyz","decor_id":"d1","decor_image_url":"http://x","scene_name":"garden","x":100.0,"y":200.0})` returns a `DecoPlacement` instance with `position_x == 100.0`

## Risks
- **JSON key mismatch:** The backend returns `x` and `y` (or `positionX` / `positionY` depending on JSON serialization settings). Confirm the exact JSON key names from a real API call or by reading the backend's JSON serializer options before implementing `from_dict`.
- **Token access without autoload import:** If the only way to get the JWT is via `UserManager` (an autoload), `RealDecoService` cannot import it directly. Resolve by accepting a `token: String` parameter in the constructor or by reading from a project-level global that the domain/services layers are allowed to read.
- **`Array[DecoPlacement]` typed return in GDScript 4:** Typed arrays of custom RefCounted classes may require `Array[DecoPlacement]` syntax — verify this compiles in the project's Godot version. Fall back to untyped `Array` if needed and document the deviation.
