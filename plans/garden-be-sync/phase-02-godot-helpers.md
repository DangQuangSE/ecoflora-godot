# Phase 2: Godot Helpers

## Layer
`services/` (GardenService.gd — domain parsing) + `autoloads/` (InventoryManager.gd, UserManager.gd)

## Files

| File | Layer | Change |
|---|---|---|
| `services/GardenService.gd` | services/ | Add `parse_plot(d: Dictionary, templates: Dictionary) -> Plot` |
| `autoloads/InventoryManager.gd` | autoloads/ | Add `restore_item(item_id: String, qty: int) -> void` |
| `autoloads/InventoryManager.gd` | autoloads/ | Add `remove_harvest_product(product_id: String) -> void` |
| `autoloads/UserManager.gd` | autoloads/ | Add `update_currency(new_total: int) -> void` |

## Requirements
Provide the four helper methods that Phase 3 (GardenManager write ops) depends on for parsing BE
responses and executing precise snapshot-based rollbacks. All helpers must be complete and callable
before Phase 3 begins.

## Steps

1. **Add `parse_plot()` to `GardenService.gd`.**
   This is a single-item wrapper around the existing `parse_plots()` loop. It accepts one plot
   Dictionary (from the BE response envelope's `data` field) and the templates Dictionary, returns
   a single `Plot` or `null` on parse failure. Internally call the existing `parse_planted_flower()`
   for any `plantedFlower` sub-key. The method signature and body:
   ```gdscript
   func parse_plot(d: Dictionary, templates: Dictionary) -> Plot:
       var plot := Plot.new(
           str(d.get("plotId", "")),
           "",
           int(d.get("plotIndex", 0))
       )
       var pf_json: Variant = d.get("plantedFlower", null)
       if pf_json is Dictionary:
           var flower: PlantedFlower = parse_planted_flower(pf_json, templates)
           if flower != null:
               plot.plant(flower)
       return plot
   ```
   This reuses `parse_planted_flower` which already handles `currentXp`, `id`, timestamps, and
   `compute_stage_for_xp()`. No duplicate logic.

2. **Add `restore_item()` to `InventoryManager.gd`.**
   This method restores an item's quantity to an exact snapshot value (not a delta increment).
   Using the exact snapshot prevents drift when a concurrent session also consumed the item between
   our tap and the rollback. Find the item by `item_id` (the InventoryItem's `.id` field, not
   `reference_id`). Set quantity directly, then emit `inventory_updated`.
   ```gdscript
   func restore_item(item_id: String, qty: int) -> void:
       for item: InventoryItem in _inventory.items:
           if item.id == item_id:
               item.quantity = qty
               inventory_updated.emit(_inventory)
               return
       push_warning("InventoryManager.restore_item: item_id '%s' not found" % item_id)
   ```
   Note: `item_id` is the InventoryItem's own UUID (`.id`), not the `reference_id` / template ID.
   The snapshot captured in Phase 3 will store `item.id` alongside `item.quantity`.

3. **Add `remove_harvest_product()` to `InventoryManager.gd`.**
   This is the rollback counterpart to the existing `add_harvest_product()`. Used only when a
   harvest BE call fails after the optimistic `add_harvest_product()` was already called. Locate
   the harvest product by `product_id` (the `harvest_product_id` field). If quantity is 1, remove
   the entry entirely. If quantity > 1, decrement by 1. Emit `inventory_updated` in both branches.
   ```gdscript
   func remove_harvest_product(product_id: String) -> void:
       var existing: InventoryItem = _inventory.find_harvest_product(product_id)
       if existing == null:
           push_warning("InventoryManager.remove_harvest_product: product '%s' not found" % product_id)
           return
       if existing.quantity <= 1:
           _inventory.items.erase(existing)
       else:
           existing.quantity -= 1
       inventory_updated.emit(_inventory)
   ```
   Note: `add_harvest_product` is only called on the harvest SUCCESS path in Phase 3 (not
   optimistically), so `remove_harvest_product` is only called if `add_harvest_product` was called
   first. This asymmetry is intentional — see Phase 3 for harvest flow ordering.

4. **Add `update_currency()` to `UserManager.gd`.**
   Sets the internal `_profile.currency` field to the authoritative value returned by the harvest
   endpoint and emits the existing `xp_gained` signal with amount 0 to trigger HUD refresh (same
   pattern used by `fetch_profile_async` for non-XP refreshes).
   ```gdscript
   func update_currency(new_total: int) -> void:
       _profile.currency = new_total
       xp_gained.emit(0)  # triggers HUD refresh — same pattern as fetch_profile_async
   ```
   Check that `UserProfile` has a `currency` field. If the field is named differently (e.g.,
   `coins` or `balance`), use the correct field name from `domain/UserProfile.gd`.

5. **Verify `find_harvest_product()` exists on `UserInventory`.**
   `InventoryManager.remove_harvest_product()` calls `_inventory.find_harvest_product(product_id)`.
   The existing `add_harvest_product()` in InventoryManager.gd already calls this method, so it
   must exist — confirm in `domain/UserInventory.gd` that the method is present and returns
   `InventoryItem` or `null`. No change needed if confirmed; add it if missing.

6. **Confirm `InventoryItem` has an `id` field accessible for snapshot capture.**
   Phase 3 will capture `var snapshot_item_id := item.id` and `var snapshot_item_qty := item.quantity`
   before consuming. Verify `InventoryItem` has a public `id: String` field (it does — confirmed
   in InventoryManager line 133: `new_item.id = "harvest_%s_%d" ...`). No change needed.

## Success Criteria
- Calling `GardenService.new().parse_plot(dict, templates)` with a valid plot Dictionary returns
  a `Plot` instance with `is_occupied = true` when `plantedFlower` is present.
- Calling `InventoryManager.restore_item(id, 3)` on an item with qty=1 sets its qty to 3 and
  emits `inventory_updated`.
- Calling `InventoryManager.remove_harvest_product("harvest_rose_bloom")` when qty=1 removes
  the entry from `_inventory.items`. When qty=2, decrements to 1.
- Calling `UserManager.update_currency(500)` sets `_profile.currency` to 500 and emits
  `xp_gained(0)`.

## Risks
- `UserProfile.currency` field name mismatch: if the field is named differently, `update_currency`
  will silently create a new dynamic property instead of updating the right one. Mitigation:
  grep `domain/UserProfile.gd` for the currency field name before writing the method (step 4).
- `find_harvest_product` signature may expect a different key type. Mitigation: step 5 explicitly
  checks the method exists before Phase 3 implementation begins.

## Testing
testing: skipped (--no-test mode)

## Story Coverage
- P1: `restore_item()` enables precise rollback (exact snapshot qty, not delta)
- P2: `parse_plot()` enables authoritative XP overwrite from care response
- P3: `update_currency()` enables immediate HUD currency update on successful harvest
