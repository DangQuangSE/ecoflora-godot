# Spec: Garden Gameplay BE Integration

**Date:** 2026-05-30
**Status:** Draft — ready for /ck:plan

---

## Problem Statement

All four garden write operations (plant, water, fertilize, harvest) are mock-local: they mutate
in-memory state and simulate a one-frame async delay. Real BE endpoints exist and work for all
four actions. The game currently has no persistence — closing the app loses any care/harvest
progress within the session. Godot's item consumption is unvalidated by the server.

---

## User Stories

### P1 — Must Have

- As a player, planting a flower consumes 1 seed from my inventory and creates a PlantedFlower
  on BE, so that my garden persists when I reopen the app.
- As a player, using a watering can / fertilizer / pesticide consumes 1 item from my inventory
  and BE awards XP, returning the authoritative `newXp` so the plant's stage is always correct.
- As a player, harvesting a fully-grown plant clears the plot on BE and credits my currency
  balance with the flower's base price.
- As a player, if any BE call fails (network error, 4xx), local state is rolled back — item is
  restored, XP reverts, plot returns to pre-action state. No phantom progress.

### P2 — Should Have

- As a player, the XP float label (`+X XP`) appears immediately on tap (optimistic), not after
  the BE round-trip.
- As a player, a plot is locked during a BE call — tapping it again does nothing until the
  response arrives.
- As a player, if BE returns a different XP than my optimistic guess (because `ReceivedExp`
  differs per item tier), my plant's stage corrects itself silently within 2 seconds.

### P3 — Nice to Have

- As a player, my currency total in the HUD updates immediately after a successful harvest
  without needing to re-fetch my profile.
- As a player, I see the item quantity in my inventory decrease immediately on tap, then correct
  if BE disagrees (e.g., BE already had qty=0 due to a race from another session).

---

## Success Criteria

- **Plant:** Seed quantity decreases by 1 locally on tap. BE creates PlantedFlower (verify via
  GET /api/garden on fresh boot — plot is occupied). If BE returns 4xx, seed quantity is restored
  and plot is cleared.
- **Care (water/fertilize/pesticide):** Item quantity decreases by 1 locally on tap. XP float
  appears within 100ms. Within 2s, BE authoritative XP is applied. If item qty was already 0 on
  BE, 400 triggers rollback and item is restored to pre-tap quantity.
- **No action possible** when item or seed quantity = 0 — guard fires before any local mutation.
- **Harvest:** Plot clears locally on tap. BE records harvest and returns `newCurrencyTotal`.
  UserManager currency updates to match. If BE fails, plot is restored (flower reappears).
- **`is_pending_sync = true`** blocks duplicate actions for the duration of every in-flight request.
- **Spam-click protection (BE):** BE inventory decrement is atomic — if 3 concurrent care requests arrive and item qty = 1, exactly 1 succeeds (200), the other 2 get 400 `InsufficientItem`. Inventory never goes negative.
- **Precise rollback:** on any care failure, client restores item quantity to the exact snapshot value captured before the tap (not `qty + 1` — uses snapshot to handle concurrent session drift). XP reverts to pre-tap value captured in snapshot.
- All four actions work correctly with `use_mock = false` and BE running locally.

---

## BE Changes Required

### Application/Services/GardenService.cs — CareForFlowerAsync

Remove the cooldown check block (lines ~134–145 in current file). The block that reads:

```
if (lastCareAt.HasValue) {
    var elapsedSeconds = ...
    if (elapsedSeconds < careItem.Item.CooldownTime)
        return (null, ApiError.Create(400, Constant.Error.CareOnCooldown));
}
```

Deletion only — no new logic needed. Inventory-quantity check already exists above it.
`LastWateredAt/LastFertilizedAt/LastPesticideAt` are still written (for analytics), just not
used for gate-keeping.

### Domain/Entities/Item.cs — CooldownTime field

Keep the column. Set `CooldownTime = 0` for all items created going forward (already the
default in the constructor). No migration required.

### Application/Services/InventoryService.cs — Atomic decrement

The inventory decrement inside `CareForFlowerAsync` (or wherever item qty is reduced) **must use a database-level atomic operation**, not a read-then-write:

```csharp
// Wrong (race condition — 3 concurrent requests all read qty=1, all pass, qty goes to -2):
var item = await _unitOfWork.Inventories.GetInventoryItemAsync(...);
if (item.Quantity <= 0) return (null, ApiError.Create(400, Constant.Error.InsufficientItem));
item.Quantity -= 1;

// Correct (atomic — database rejects if qty would go below 0):
var affected = await _unitOfWork.Inventories.DecrementQuantityIfPositiveAsync(inventoryItemId);
if (affected == 0) return (null, ApiError.Create(400, Constant.Error.InsufficientItem));
```

`DecrementQuantityIfPositiveAsync` executes: `UPDATE inventory_items SET quantity = quantity - 1 WHERE id = @id AND quantity > 0` and returns rows affected. If 0 rows → item was already 0 → return 400.

### No new endpoints — existing contract is sufficient

| Endpoint | Request | Response key fields used by Godot |
|---|---|---|
| `POST /api/garden/plots/{plotId}/plant` | `{ flowerTemplateId: "uuid" }` | `data.plotId`, `data.plantedFlower` (PlantedFlowerDto) |
| `POST /api/garden/plots/{plotId}/care` | `{ action: 0\|1\|2 }` | `data.updatedPlot.plantedFlower.currentXp`, `data.remainingQuantity` |
| `POST /api/garden/plots/{plotId}/harvest` | _(no body)_ | `data.newCurrencyTotal` |

`CareAction` enum: `Water=0, Fertilize=1, Pesticide=2` — matches `ItemType` on BE and maps to
Godot's three separate care methods.

---

## Godot Changes Required

### GardenManager.gd

**Refactor care methods into shared internal helper.** `water()`, `fertilize()`, `pesticide()`
are structurally identical (optimistic XP delta + HTTP POST + rollback). Extract a private
`_care_action(plot_id: String, action_value: int)` method. Each public method calls it with
`action_value` 0, 1, 2 respectively.

**`_care_action(plot_id, action_value)` — full flow:**
1. Guard: plot must be occupied and not `is_pending_sync`.
2. Guard: `InventoryManager` must have quantity > 0 for the selected item.
3. Snapshot: capture `prev_xp`, `prev_stage`, `prev_item_qty` (exact integer value before consume) — all three needed for precise rollback.
4. Optimistic mutate: `InventoryManager.consume_item(ref_id)`, apply XP delta locally
   (use `item.received_exp` from `_item_cache` if available, else local constant), emit
   `plant_xp_gained`, emit `plots_updated`.
5. HTTP POST `/api/garden/plots/{plot_id}/care` with `{ "action": action_value }`.
6. On 200: parse `data.updatedPlot.plantedFlower.currentXp`, overwrite `plot.current_plant.current_xp`,
   recompute stage. Update `InventoryItem.quantity` to `data.remainingQuantity`. Emit signals.
7. On any error (4xx, network, timeout): restore using snapshot — `plant.current_xp = prev_xp`,
   recompute stage from `prev_xp`, `item.quantity = prev_item_qty` (not `+= 1` — snapshot prevents
   drift if multiple sessions modify the same inventory). Re-emit `inventory_updated`, `plots_updated`.
8. Clear `is_pending_sync` in both branches.

**`plant(plot_id, flower_template_id)` — full flow:**
1. Existing guards (plot not occupied, template found, `consume_seed` succeeds).
2. Create local `PlantedFlower` with `id = ""` (empty until BE confirms).
3. HTTP POST `/api/garden/plots/{plot_id}/plant` with `{ "flowerTemplateId": flower_template_id }`.
4. On 200: parse `data` (PlotDto) via `GardenService.parse_plots([data], _templates)` or a new
   `GardenService.parse_plot(data, _templates)` helper. Overwrite local plot with parsed result
   (authoritative flower ID set).
5. On error: restore seed quantity (`InventoryManager` restore), call `plot.clear()`, emit
   `plant_failed`, emit `plots_updated`.

**`harvest(plot_id)` — full flow:**
1. Existing guards (plot occupied, max stage reached).
2. Snapshot: `product_id`, full `PlantedFlower` reference, current currency.
3. Optimistic: `plot.clear()`, emit `plots_updated`, emit `harvest_completed`.
4. HTTP POST `/api/garden/plots/{plot_id}/harvest` (no body).
5. On 200: call `UserManager.update_currency(data.newCurrencyTotal)`. Add harvest product
   via `InventoryManager.add_harvest_product(product_id)`.
6. On error: restore flower to plot (`plot.plant(snapshot_flower)`), emit `plots_updated`.
   Do NOT call `add_harvest_product` on error path.

**New HTTPRequest node for write ops:** add `_http_write: HTTPRequest` child (separate from
`_http_garden` which handles GET). One write request at a time is enforced by `is_pending_sync`
per plot — concurrent writes to different plots are fine since they use different plot guards.

### GardenService.gd

Add `parse_plot(d: Dictionary, templates: Dictionary) -> Plot` — single-item version of the
existing `parse_plots` array loop. Reused by plant and care response parsing.

The existing `parse_planted_flower` is already sufficient for parsing the `updatedPlot.plantedFlower`
from care responses.

### UserManager.gd

Add `update_currency(new_total: int) -> void` — sets internal currency field and emits the
existing `profile_updated` signal so HUD refreshes.

### InventoryManager.gd

Add `restore_item(item_id: String, quantity_to_restore: int) -> void` — increments quantity by
the given amount and emits `inventory_updated`. Used by rollback paths. More explicit than
calling `consume_item` in reverse.

---

## HTTP Helper Notes

- All write POSTs use `UserManager.get_auth_header()` for Bearer token.
- Body serialization: `JSON.stringify({ "action": action_value })` etc.
- Response parsing: use existing `HttpHelper.unwrap_envelope(envelope)` to get `data` dict.
- On 401 in any write response: call `UserManager.handle_401()` before rollback.

---

## Open Questions

- Should `pesticide` have a different XP value than `fertilizer`? Both map to `ItemType` values
  with individual `ReceivedExp` in DB. After BE integration XP comes from BE response — Godot's
  local constants become fallback-only for the optimistic guess. No open issue in practice.
- What if `_http_write` is already in use when a second plot's write fires? Answer: each plot's
  `is_pending_sync = true` guard prevents only same-plot re-entry. A single `_http_write` node
  cannot multiplex. Either (a) add one `HTTPRequest` per write op type (plant/care/harvest),
  or (b) add a per-plot `HTTPRequest` node dynamically. Option (a) is simplest — 2 nodes
  (one for care, one for plant/harvest since those can't fire simultaneously on same plot).
  Decide during implementation.

---

## Out of Scope

- Focus session → item grant (separate feature, already planned)
- Shop purchase flow (separate feature)
- Cooldown UI/timer removal from existing scenes (no cooldown UI was ever built — N/A)
- Harvest product sync to BE (local-only, documented as intentional in existing spec)
- Real-time conflict resolution between sessions (no WebSocket)
