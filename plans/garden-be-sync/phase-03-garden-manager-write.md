# Phase 3: GardenManager Write Ops

## Layer
`autoloads/GardenManager.gd`

## Files

| File | Layer | Change |
|---|---|---|
| `autoloads/GardenManager.gd` | autoloads/ | Add 3 HTTPRequest nodes; replace stub water/fertilize/pesticide with `_care_action()`; replace stub plant/harvest with real HTTP POST + rollback flows; move `harvest_completed` emit to success branch |

## Prerequisites
`use_mock = false` integration testing requires **Phase 01 BE deployed** at `localhost:5226`.
Godot code can be written before Phase 01 is deployed (mock path still works), but activating
`use_mock = false` against the old cooldown-gated BE will trigger rollback on every second care
request — making rollback appear to work when it is actually firing against a deprecated BE behavior.

## Requirements
All four garden write operations (water, fertilize, pesticide, plant, harvest) must POST to their
real BE endpoints, apply optimistic local mutation immediately, and roll back precisely to
pre-tap state on any failure — using deep-copy snapshots captured before any mutation.

## Steps

1. **Add three dedicated HTTPRequest nodes in `_ready()` under the `if not use_mock:` block.**
   After the existing `_http_garden` node setup, add:
   ```gdscript
   _http_care = HTTPRequest.new()
   _http_care.timeout = 15.0
   add_child(_http_care)

   _http_plant = HTTPRequest.new()
   _http_plant.timeout = 15.0
   add_child(_http_plant)

   _http_harvest = HTTPRequest.new()
   _http_harvest.timeout = 15.0
   add_child(_http_harvest)
   ```
   Declare persistent write nodes for plant and harvest only:
   ```gdscript
   var _http_plant: HTTPRequest
   var _http_harvest: HTTPRequest
   ```
   **Care requests use dynamic HTTPRequest nodes** (one created per call, freed after response).
   This gives true per-plot independence — plot A and plot B can water simultaneously without
   any shared node contention. The per-plot `is_pending_sync` flag still prevents same-plot
   double-tap. `_http_plant` / `_http_harvest` are static because plant and harvest on the
   same plot are sequential by `is_pending_sync` — no concurrency possible.

2. **Extract `_care_action()` private helper and wire `water()`, `fertilize()`, `pesticide()` to it.**
   The three methods are structurally identical. Replace their bodies with single-line delegations:
   ```gdscript
   func water(plot_id: String) -> void:
       if use_mock:
           # existing mock body unchanged
           ...
           return
       await _care_action(plot_id, 0)

   func fertilize(plot_id: String) -> void:
       if use_mock:
           ...
           return
       await _care_action(plot_id, 1)

   func pesticide(plot_id: String) -> void:
       if use_mock:
           ...
           return
       await _care_action(plot_id, 2)
   ```
   Keep the entire existing mock body inside each method's `if use_mock:` block — do not delete it.

3. **Implement `_care_action(plot_id: String, action_value: int) -> void`.**
   This is the core of the care flow. Full implementation:

   **Guards and snapshot (BEFORE any mutation):**
   ```gdscript
   func _care_action(plot_id: String, action_value: int) -> void:
       var plot: Plot = _find_plot(plot_id)
       if plot == null or not plot.is_occupied or plot.is_pending_sync:
           return
       var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
       if template == null:
           return

       # Determine which item ref_id maps to this action
       var item_ref_id := _action_to_item_ref(action_value)
       if item_ref_id.is_empty():
           return
       if not InventoryManager.has_item(item_ref_id):
           return

       # Snapshot BEFORE any mutation — field values only, not references
       var snapshot_plot := plot.deep_copy()
       var inv_item: InventoryItem = InventoryManager.get_inventory().find_by_reference_id(item_ref_id)
       var snapshot_item_id: String  = inv_item.id
       var snapshot_item_qty: int    = inv_item.quantity
   ```

   **Optimistic mutation:**
   ```gdscript
       plot.is_pending_sync = true
       InventoryManager.consume_item(item_ref_id)

       # Use received_exp from item cache if available, else fall back to local constant
       var xp_delta: int = _get_item_exp(action_value)
       plot.current_plant.current_xp += xp_delta
       plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
       plant_xp_gained.emit(plot_id, xp_delta)
       plots_updated.emit(_plots)
   ```

   **HTTP POST:**
   ```gdscript
       var url := UserManager.base_url + "/api/garden/plots/%s/care" % plot_id
       var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
       var body := JSON.stringify({ "action": action_value })
       # Dynamic node — each care call gets its own HTTPRequest; true per-plot independence
       var http := HTTPRequest.new()
       http.timeout = 15.0
       add_child(http)
       var err := http.request(url, headers, HTTPClient.METHOD_POST, body)
       if err != OK:
           http.queue_free()
           _care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)
           return
       var raw: Variant = await http.request_completed
       http.queue_free()
       var status: int = raw[1]
       var bytes: PackedByteArray = raw[3]
   ```

   **Success path (200):**
   ```gdscript
       if status == 200:
           var json := JSON.new()
           var parse_ok := json.parse(bytes.get_string_from_utf8()) == OK
           var data: Variant = HttpHelper.unwrap_envelope(json.get_data()) if parse_ok else null
           if data is Dictionary:
               var updated_plot_dict: Variant = data.get("updatedPlot", null)
               if updated_plot_dict is Dictionary:
                   var pf_dict: Variant = (updated_plot_dict as Dictionary).get("plantedFlower", null)
                   if pf_dict is Dictionary:
                       var garden_svc := GardenService.new()
                       var auth_flower: PlantedFlower = garden_svc.parse_planted_flower(pf_dict, _templates)
                       if auth_flower != null:
                           plot.current_plant.current_xp = auth_flower.current_xp
                           plot.current_plant.current_stage = auth_flower.current_stage
               var remaining: Variant = data.get("remainingQuantity", null)
               if remaining != null:
                   InventoryManager.restore_item(snapshot_item_id, int(remaining))
           else:
               # 200 with missing/malformed envelope is treated as failure — roll back
               push_warning("GardenManager._care_action: 200 but envelope malformed — rolling back")
               _care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)
   ```

   **Failure path (4xx / network error):**
   ```gdscript
       else:
           if status == 401:
               UserManager.handle_401()
           _care_rollback(plot, snapshot_plot, snapshot_item_id, snapshot_item_qty)
   ```

   **Always clear pending sync (runs in both branches):**
   ```gdscript
       plot.is_pending_sync = false
       plots_updated.emit(_plots)
   ```

   **Rollback helper** — clears `is_pending_sync` so the plot is never permanently locked:
   ```gdscript
   func _care_rollback(plot: Plot, snapshot: Plot, item_id: String, item_qty: int) -> void:
       plot.current_plant.current_xp    = snapshot.current_plant.current_xp
       plot.current_plant.current_stage = snapshot.current_plant.current_stage
       plot.is_pending_sync = false  # critical — prevents permanent lock on err != OK path
       InventoryManager.restore_item(item_id, item_qty)
       # do NOT emit plots_updated here — the tail of _care_action emits it once for both branches
   ```
   Field-by-field restore is required because `plot` is a reference inside `_plots` — assigning
   `plot = snapshot` would replace the local variable only, leaving `_plots` stale.

4. **Add `_action_to_item_ref()` and `_get_item_exp()` private helpers.**
   These map the integer action value to an inventory reference ID and a local fallback XP constant.
   ```gdscript
   func _action_to_item_ref(action_value: int) -> String:
       # Search _item_cache for the item whose type matches the action
       # ItemType: Water=0, Fertilize=1, Pesticide=2 (matches CareAction enum on BE)
       for key: String in _item_cache:
           var item_data: Dictionary = _item_cache[key]
           if int(item_data.get("type", -1)) == action_value:
               return key
       return ""

   func _get_item_exp(action_value: int) -> int:
       # Try to read received_exp from item cache; fall back to local constants
       for key: String in _item_cache:
           var item_data: Dictionary = _item_cache[key]
           if int(item_data.get("type", -1)) == action_value:
               return int(item_data.get("received_exp", 0))
       # Fallback constants (used when catalog not yet loaded or use_mock=true)
       match action_value:
           0: return 20  # Water
           1: return 50  # Fertilize
           2: return 50  # Pesticide
       return 0
   ```

5. **Rewrite `plant()` with real HTTP POST.**
   Replace the `await get_tree().process_frame` stub body (keep the `if use_mock:` early return):
   ```gdscript
   func plant(plot_id: String, flower_template_id: String) -> void:
       if use_mock:
           # existing mock body unchanged
           ...
           return

       var plot: Plot = _find_plot(plot_id)
       if plot == null or plot.is_occupied or plot.is_pending_sync:
           plant_failed.emit(plot_id, "not_available")
           return
       var template: FlowerTemplate = _templates.get(flower_template_id)
       if template == null:
           plant_failed.emit(plot_id, "unknown_template")
           return

       # Find seed item and snapshot its qty BEFORE consuming
       var seed_item: InventoryItem = InventoryManager.get_inventory().find_by_reference_id(flower_template_id)
       if seed_item == null or seed_item.quantity <= 0:
           plant_failed.emit(plot_id, "no_seed")
           return
       var snapshot_seed_id: String  = seed_item.id
       var snapshot_seed_qty: int    = seed_item.quantity

       # Optimistic: consume seed and plant a placeholder flower (id = "" until BE confirms)
       if not InventoryManager.consume_seed(flower_template_id):
           plant_failed.emit(plot_id, "no_seed")
           return
       plot.is_pending_sync = true
       var flower := PlantedFlower.new(flower_template_id, "")
       flower.current_xp    = 0
       flower.current_stage = template.compute_stage_for_xp(0)
       plot.plant(flower)
       plots_updated.emit(_plots)

       # HTTP POST
       var url := UserManager.base_url + "/api/garden/plots/%s/plant" % plot_id
       var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
       var body := JSON.stringify({ "flowerTemplateId": flower_template_id })
       var err := _http_plant.request(url, headers, HTTPClient.METHOD_POST, body)
       if err != OK:
           InventoryManager.restore_item(snapshot_seed_id, snapshot_seed_qty)
           plot.clear()
           plot.is_pending_sync = false
           plant_failed.emit(plot_id, "request_error")
           plots_updated.emit(_plots)
           return

       var raw: Variant = await _http_plant.request_completed
       var status: int = raw[1]
       var bytes: PackedByteArray = raw[3]

       if status == 200:
           var json := JSON.new()
           if json.parse(bytes.get_string_from_utf8()) == OK:
               var envelope: Variant = json.get_data()
               var data: Variant = HttpHelper.unwrap_envelope(envelope)
               if data is Dictionary:
                   var garden_svc := GardenService.new()
                   var auth_plot: Plot = garden_svc.parse_plot(data, _templates)
                   if auth_plot != null and auth_plot.is_occupied:
                       # Overwrite with authoritative IDs (especially flower.id from BE)
                       plot.plant(auth_plot.current_plant)
       else:
           if status == 401:
               UserManager.handle_401()
           InventoryManager.restore_item(snapshot_seed_id, snapshot_seed_qty)
           plot.clear()
           plant_failed.emit(plot_id, "be_error_%d" % status)

       plot.is_pending_sync = false
       plots_updated.emit(_plots)
   ```

6. **Rewrite `harvest()` with real HTTP POST.**
   Key ordering rule: `harvest_completed` must emit AFTER BE confirms (200), not optimistically,
   because `UserManager._on_harvest_completed` adds XP from the signal. Moving it to the success
   branch prevents phantom XP on rollback.
   ```gdscript
   func harvest(plot_id: String) -> void:
       if use_mock:
           # existing mock body unchanged — but note: mock still emits harvest_completed early
           ...
           return

       var plot: Plot = _find_plot(plot_id)
       if plot == null or not plot.is_occupied or plot.is_pending_sync:
           return
       var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
       if template == null:
           return
       if plot.current_plant.current_stage < template.get_max_stage_level():
           return

       # Snapshot: full flower reference (deep copy) for rollback
       var snapshot_flower: PlantedFlower = plot.current_plant.deep_copy()
       var product_id := template.harvest_product_id

       # Optimistic: clear plot locally, do NOT emit harvest_completed yet
       plot.is_pending_sync = true
       plot.clear()
       plots_updated.emit(_plots)

       # HTTP POST (no body)
       var url := UserManager.base_url + "/api/garden/plots/%s/harvest" % plot_id
       var headers := PackedStringArray(["Content-Type: application/json", UserManager.get_auth_header()])
       var err := _http_harvest.request(url, headers, HTTPClient.METHOD_POST, "")
       if err != OK:
           plot.plant(snapshot_flower)
           plot.is_pending_sync = false
           plots_updated.emit(_plots)
           return

       var raw: Variant = await _http_harvest.request_completed
       var status: int = raw[1]
       var bytes: PackedByteArray = raw[3]

       if status == 200:
           var json := JSON.new()
           if json.parse(bytes.get_string_from_utf8()) == OK:
               var envelope: Variant = json.get_data()
               var data: Variant = HttpHelper.unwrap_envelope(envelope)
               if data is Dictionary:
                   var new_total: Variant = data.get("newCurrencyTotal", null)
                   if new_total != null:
                       UserManager.update_currency(int(new_total))
           # Add harvest product AFTER BE confirms — not before
           InventoryManager.add_harvest_product(product_id)
           # NOW emit harvest_completed so UserManager adds XP
           harvest_completed.emit(plot_id, product_id)
       else:
           if status == 401:
               UserManager.handle_401()
           # Rollback: restore flower to plot
           plot.plant(snapshot_flower)
           plots_updated.emit(_plots)

       plot.is_pending_sync = false
       plots_updated.emit(_plots)
   ```

7. **Add `pesticide()` to `_on_plot_action` dispatch and verify `use_mock` guard in mock paths.**
   Check `_on_plot_action` match block — it currently handles `"water"`, `"fertilize"`, but not
   `"pesticide"`. Add `"pesticide": pesticide(plot_id)`. Also confirm that mock paths inside each
   method (from the existing stubs) still work correctly with the new `if use_mock:` guard structure.

## Success Criteria
- With `use_mock = false` and BE running: planting a flower removes 1 seed locally, then the
  planted flower's ID changes from `""` to the real UUID within ~2 seconds (visible via a debug
  print of `plot.current_plant.id` after the await).
- Watering a plot locally shows the XP float immediately, then the XP value corrects to the BE
  authoritative value from `data.updatedPlot.plantedFlower.currentXp` within ~2 seconds.
- Care when item qty = 0 fires no HTTP request and no local state changes.
- Simulating a 400 response (by planting when seed qty = 0 on BE but qty = 1 locally) restores
  seed quantity to the exact snapshot value and clears the plot.
- Harvesting a max-stage plant: plot clears immediately, `UserManager.get_profile().currency`
  updates to `newCurrencyTotal` from response, `harvest_completed` signal fires once on success.
- `harvest_completed` does NOT fire if BE returns a non-200 response; flower reappears on plot.
- `is_pending_sync` returns to `false` on both success and failure branches for all three ops.

## Risks
- `_http_care` is a single node — if two different plots fire `_care_action` concurrently, the
  second `await _http_care.request_completed` will receive the response for the first request.
  Mitigation: the single global `_http_care` is a known limitation documented in the spec's Open
  Questions section. Per-plot `is_pending_sync` only blocks same-plot retries. If concurrent
  multi-plot care becomes a real use case, each plot needs its own HTTPRequest node. Accept for
  now — single-plot care is the dominant gameplay pattern.
- `plot.plant(snapshot_flower)` in harvest rollback passes a deep-copy — this is correct and
  safe. The snapshot's `id` is the real BE UUID (not `""`), so the flower reappears with the
  correct identity.
- `UserManager._on_harvest_completed` is connected to `harvest_completed` and calls `_profile.add_xp()`.
  Moving the signal to the success branch means XP is only added when BE confirms — this is
  correct behavior but breaks the mock path which emits the signal early. The mock path's existing
  behavior is acceptable for development; document in code comments.

## Testing
testing: skipped (--no-test mode)

## Story Coverage
- P1: all four write ops wired to BE; 4xx triggers rollback; no phantom progress
- P2: XP float emits immediately (optimistic `plant_xp_gained`); `is_pending_sync` blocks double-tap; BE XP corrects within 2s
- P3: currency updates immediately on harvest 200; item qty decreases immediately on care/plant tap
