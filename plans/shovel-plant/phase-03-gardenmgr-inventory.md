# Phase 3: GardenManager dig_up() + InventoryManager restore_seed()

## Requirements

Add `GardenManager.dig_up(plot_id: String) -> void` following the exact optimistic UI pattern as the existing harvest() function. Add `InventoryManager.restore_seed(flower_template_id: String) -> void` to increment a seed item's quantity, creating it if absent.

## Steps

1. **Add HTTP request object to GardenManager** — In `d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\autoloads\GardenManager.gd`, add a new field `var _http_dig_up: HTTPRequest` and a flag `var _dig_up_in_flight: bool = false` (around line 26 after `_http_harvest`). In `_ready()`, instantiate `_http_dig_up = HTTPRequest.new(); _http_dig_up.timeout = 15.0; add_child(_http_dig_up)` (mirror the pattern for `_http_harvest` at lines 65–68). Ensure this only happens when `not use_mock`.

2. **Add dig_up function skeleton** — After the `harvest()` function (around line 627), add:
   ```gdscript
   func dig_up(plot_id: String) -> void:
   ```
   This function should accept only plot_id and no other parameters (unlike harvest which returns a product).

3. **Implement guard checks** — At the start of dig_up(): Check if `_dig_up_in_flight` and return early with a toast if true. Fetch the plot via `_find_plot(plot_id)`. Return early if plot is null, not occupied, or `is_pending_sync`. Do NOT check `current_stage` like harvest does (spec says dig-up works at any stage).

4. **Snapshot and optimistic clear** — Before relying on it, open `PlantedFlower.deep_copy()` (or equivalent) and confirm it copies every field used by the UI/rollback (flower_template_id, current_xp, current_stage, planted_at, last_watered_at, any cooldown timestamps) — an incomplete deep copy means rollback after an HTTP error silently restores a flower missing XP/stage. Fix `deep_copy()` if any field is missing before relying on it here. Store `var snapshot_flower: PlantedFlower = plot.current_plant.deep_copy()`. Store the flower's template ID: `var flower_template_id := plot.current_plant.flower_template_id`. Set `plot.is_pending_sync = true`. Call `plot.clear()` to empty the plot immediately. Emit `plots_updated.emit(_plots)` so UI sees the empty plot instantly (optimistic). Play audio (optional; use same or different SFX than harvest): `AudioManager.play_sfx("res://sounds/dig.wav")` or similar if file exists; if not, skip.

5. **Handle mock mode** — If `use_mock`, set `is_pending_sync = true`, clear plot, emit, wait one frame, then finalize: set `is_pending_sync = false`, call `InventoryManager.restore_seed(flower_template_id)`, emit, and show toast "Đã xúc cây" + return.

6. **Make HTTP request** — If not mock: build URL `var url := UserManager.base_url + "/api/garden/plots/%s/dig-up" % plot_id`. Set `_dig_up_in_flight = true`. Make POST request: `var err := _http_dig_up.request(url, headers, HTTPClient.METHOD_POST, "")` (empty body; all params in URL and auth header). If error, set `_dig_up_in_flight = false`, rollback plot via `plot.plant(snapshot_flower)`, set `is_pending_sync = false`, emit, show toast, return.

7. **Corrected: await and validate response by status code only, no body parsing needed.** `var raw: Variant = await _http_dig_up.request_completed`. Set `_dig_up_in_flight = false`. Check `var status: int = raw[1]`. The response body is intentionally never parsed: `flower_template_id` is already known locally from the pre-clear snapshot (captured in step 4), so there is nothing in `DigUpRewardDto`'s body that the client needs to read back — this exactly mirrors the actual convention in `harvest()` (`GardenManager.gd`), which also calls `InventoryManager.add_harvest_product(product_id)` using the locally-known `product_id`, not a value parsed from the response. If status == 200: success path. If status == 401: call `UserManager.handle_401()` (in addition to falling through to rollback, same as harvest's else-branch). On any non-200 status: rollback — `plot.plant(snapshot_flower)` — then unconditionally set `plot.is_pending_sync = false` right after (not nested in a branch that could be skipped), `plots_updated.emit(_plots)`, toast "Xúc cây thất bại. Vui lòng thử lại." A plot must never remain stuck with `is_pending_sync = true`.

8. **On success** — After status 200 validation: set `plot.is_pending_sync = false`. Call `InventoryManager.restore_seed(flower_template_id)`. Emit `plots_updated.emit(_plots)`. Show toast "Xúc cây thành công." (or similar). Do NOT emit any harvest-like signals.

9. **Ensure cleanup in _exit_tree** — Update the existing `_exit_tree()` function to also cancel `_http_dig_up` if in-flight.

## Steps for InventoryManager.restore_seed()

10. **Add restore_seed function** — In `d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\autoloads\InventoryManager.gd`, after `add_harvest_product()`, add:
    ```gdscript
    func restore_seed(flower_template_id: String) -> void:
    ```

11. **Corrected: `find_by_reference_id` already disambiguates by category — no new lookup method needed.** Direct inspection of `domain/InventoryItem.gd` and `domain/UserInventory.gd` confirms `find_by_reference_id(ref_id)` calls `item.get_reference_id()` per item, which is itself a category-dispatched match (`Category.SEED → flower_template_id`, `Category.HARVEST_PRODUCT → harvest_product_id`, etc. — see `InventoryItem.gd:17-25`). A HARVEST_PRODUCT item's `flower_template_id` field is never populated, so it can never collide with a SEED lookup by the same string — this is the exact same pattern already used safely by `plant()` and `consume_seed()` in this file. No "Category mismatch" risk exists; no new method was added. Implementation: `find_by_reference_id(flower_template_id)`; if found and `category == InventoryItem.Category.SEED`, `item.quantity += 1`; else create a new `InventoryItem` with `id = "seed_%s_%d" % [flower_template_id, _inventory.items.size()]` (mirrors `add_harvest_product()`'s id-naming convention), `flower_template_id = flower_template_id` (not `item_id` — that field is for CONSUMABLE), `category = InventoryItem.Category.SEED`, `quantity = 1`, appended to `_inventory.items`.

12. **Emit signal** — After adding or incrementing, call `inventory_updated.emit(_inventory)` so UI (inventory panel, item count displays) reflects the new seed count.

13. **Log warnings if needed** — If item lookup fails or category is wrong, use `push_warning()` to log it (but don't block the operation).

## Success Criteria

- GardenManager.dig_up(plot_id) compiles without errors and is callable.
- Calling dig_up on an empty plot returns early without crashing.
- Calling dig_up on an occupied plot: plot.is_pending_sync becomes true, plot clears optimistically, plots_updated is emitted within <100ms.
- Mock mode dig_up completes in 1 frame, clears plot, increments seed, shows toast, and leaves is_pending_sync = false.
- HTTP dig_up request is made to correct URL with correct auth header and method (POST, empty body).
- On HTTP 200 success: is_pending_sync = false, InventoryManager.restore_seed() is called, plots_updated emitted again, toast shown.
- On HTTP error (non-200): plot is restored to original state (plot.plant(snapshot)), is_pending_sync = false, plots_updated emitted, toast shows error message, NO seed added to inventory.
- Calling InventoryManager.restore_seed(flower_template_id) with an existing seed increments its quantity by 1.
- Calling restore_seed() with a new flower_template_id creates a new InventoryItem with category SEED.
- inventory_updated signal is emitted after restore_seed() completes.
- Multiple dig-up calls on different plots proceed correctly without blocking (is_dig_up_in_flight flag works as guard).
- `PlantedFlower.deep_copy()` verified to copy every field the UI reads; a rollback test (Phase 5 Test 9) shows the restored plant's stage/XP/timestamps match the pre-dig-up values exactly.
- Malformed/missing-field JSON on a 200 response triggers rollback (same path as an HTTP error), never a crash or a silent inventory update with bad data.
- `is_pending_sync` is always false after dig_up() returns, on every code path (success, HTTP error, malformed response, rollback exception).
- restore_seed() never increments a HarvestProduct-category item; seed and harvest-product stacks for the same flower_template_id stay independent.

## Risks

- **Snapshot deep_copy failure** — If PlantedFlower.deep_copy() is incomplete (doesn't copy all fields), rollback will leave the plot in a weird state. Mitigation: Verify PlantedFlower.deep_copy() implementation (should copy all fields); test rollback with actual flower that has all fields set.
- **Timing issue on optimistic clear** — If UI renders the empty plot before `plot.clear()` actually runs in memory, UX glitch. Mitigation: call plot.clear() BEFORE emit plots_updated; emit is the notification that triggers view refresh.
- **Seed item category mismatch** — Verified not a risk: `InventoryItem.Category.SEED` already exists in the enum (`domain/InventoryItem.gd:4`) and is set explicitly on the new item; `find_by_reference_id` already disambiguates correctly per category (see step 11 correction above).
- **Toast not visible if modal open** — If a dialog is already open when dig_up completes, toast might not show or might be hidden. Mitigation: Toast subsystem should handle layering automatically; if not, defer toast until after dialog closes.
