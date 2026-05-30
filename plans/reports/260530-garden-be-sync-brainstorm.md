# Brainstorm: Garden Gameplay BE Integration — Wiring Write Operations

**Date:** 2026-05-30
**Context:** Phase 5 (Garden Sync) implemented GET garden. All write ops (plant/water/fertilize/harvest)
are still mock-local with TODO comments. BE already has the full CRUD surface for garden actions.

---

## Ideas Explored

### 1. Cooldown Model vs Item-Consumption Model

**Option A — Keep cooldown (original BE design):**
- `CareForFlowerAsync` already checks `CooldownTime` on the `Item` entity against `LastWateredAt/LastFertilizedAt/LastPesticideAt`.
- Godot would only need to send `{ action: 0/1/2 }` — no item ID required.
- Problem: cooldown is a server-side DB timestamp check. Godot has no shared clock, so client-side
  feedback ("still on cooldown") would require a separate GET or locally tracking the server timestamp.
  UX is poor. Items sitting in inventory have no meaning — players can never deplete them.

**Option B — Item-consumption model (chosen):**
- Each care action consumes 1 item from inventory. No cooldown timer involved.
- BE still has `CooldownTime` in the `Item` entity and `LastWateredAt` etc. in `PlantedFlower`, but
  the cooldown check logic is removed from `CareForFlowerAsync`.
- Client already calls `InventoryManager.consume_item()` locally. This becomes the optimistic step.
- BE validates item quantity > 0, decrements on its side, awards XP via `ReceivedExp` field.
- Items are earned through focus sessions/quests — giving them real scarcity and meaning.
- Verdict: **chosen.** Matches the item-grant infrastructure already built (shop, admin grant endpoint,
  focus session rewards).

**Why cooldown removal is low-risk:**
- The `LastWateredAt/LastFertilizedAt/LastPesticideAt` columns can remain in DB (no migration cost).
- They just stop being used for validation. Can repurpose later for analytics/display if needed.
- `CooldownTime` on `Item` stays as a DB column, set to 0 for all new items going forward.

### 2. Optimistic UI vs Confirm-First

**Option A — Confirm first:** Show spinner, wait for BE 200, then update XP/stage.
- Pro: No rollback complexity.
- Con: 200-500ms delay before any visual feedback. Mobile feel is sluggish. Unacceptable for a garden
  game where tapping a flower is the core loop.

**Option B — Optimistic UI with rollback (chosen):**
- Local state mutates immediately: XP increases, stage may advance, item quantity decreases.
- BE call fires async. On 200: overwrite optimistic XP/stage with authoritative `updatedPlot.plantedFlower.currentXp`.
- On error: restore previous XP, previous stage, restore item quantity.
- `is_pending_sync = true` blocks double-taps during in-flight.
- Verdict: **chosen.** Already the established pattern in CLAUDE.md.

**Important nuance found:** BE `CareResponseDto` returns `UpdatedPlot` (full PlotDto with PlantedFlowerDto),
not just `newXp`. Godot must parse `updatedPlot.plantedFlower.currentXp` and recompute stage via
`FlowerTemplate.compute_stage_for_xp()` — never trust any stage value from BE directly.

### 3. What the Care Request Needs to Send

**Current BE `CareRequest`:** `{ action: 0|1|2 }` (Water=0, Fertilize=1, Pesticide=2).
- BE looks up the item by `ItemType == (ItemType)action` in the player's inventory — it picks
  the first matching item automatically via `GetInventoryItemForCareAsync`.
- Godot does NOT need to send an `itemId`. The action enum is sufficient for BE to find and
  consume the right item.
- This is simpler than the brainstorm assumed. No contract change needed.

**What Godot must know to send the right action value:**
- `InventoryItem` has a `category` field. Items loaded from BE carry `type` (int) in `_item_cache`.
- When player selects an item and taps a plot, `InteractionManager` already routes to `water()`,
  `fertilize()`, or `pesticide()` based on selected item category. These functions already exist
  as separate methods in GardenManager — they just need the HTTP call added.

### 4. Plant Action — Who Consumes the Seed?

**Current state:** `GardenManager.plant()` calls `InventoryManager.consume_seed()` locally, then
sets `is_pending_sync = true`, creates `PlantedFlower`, and clears `is_pending_sync` after one frame.
No BE call.

**After integration:**
- Optimistic: consume seed locally + create local PlantedFlower.
- POST `/api/garden/plots/{plotId}/plant` with `{ flowerTemplateId }`.
- BE validates seed in inventory, decrements, creates `PlantedFlower` in DB.
- On 200: overwrite local plot with parsed `PlotDto` (sets authoritative `flower.id` from BE).
- On error: rollback — restore seed quantity, clear plot.

**Key insight:** BE `PlantFlowerAsync` soft-deletes the seed inventory item when quantity hits 0
(`DeleteInventoryItem`). Client must handle the case where BE returns a plot whose `plantedFlower.id`
differs from a locally-generated placeholder. The simplest fix: don't generate a local ID — leave
`flower.id = ""` until BE confirms.

### 5. Harvest Action — Currency Update Side Effect

**BE `HarvestFlowerAsync`:** soft-deletes the `PlantedFlower`, clears `plot.PlantedFlowerId`,
and increments `user.Currency` by `template.BasePrice`. Returns `HarvestRewardDto` with
`newCurrencyTotal` and a `rewardItems` list (flower name + qty=1, for display).

**Godot side:** `UserManager` tracks currency. After a successful harvest, Godot should call
`UserManager.update_currency(new_currency_total)` with the value from `HarvestRewardDto`.
This is new — currently harvest only emits `harvest_completed` and `InventoryManager.add_harvest_product`.

**Harvest product:** BE returns `rewardItems: [{ itemName, quantity }]` — this is a display hint,
not a BE inventory entry. Godot's local `add_harvest_product` behavior stays. No BE sync needed
for harvest products.

---

## User's Direction and Reasoning

- Replace cooldown model with item-consumption entirely. CooldownTime field stays in DB, value = 0.
- Optimistic UI is non-negotiable — visual feedback must be instant on mobile.
- BE is authoritative for XP/stage after a care action. Godot must apply BE's returned XP, not its
  own locally-computed delta.
- Harvest must update UserManager currency from BE response (not a separate GET /profile call).
- Rollback on any BE error (4xx or network failure) is required for all four actions.

---

## Key Findings from Code Scout

1. **BE endpoints all exist and work.** `GardenController` has plant, care, harvest. No missing endpoints.
2. **Care request is just `{ action: 0|1|2 }`.** BE auto-selects item by type. No itemId field needed.
3. **CooldownTime check is still in `GardenService.CareForFlowerAsync`** (lines 134-145). This must
   be removed/bypassed. Options: (a) set all item `CooldownTime = 0` so the check always passes,
   (b) delete the cooldown check block. Option (b) is cleaner.
4. **`CareResponseDto.RemainingQuantity`** is set to `careItem.Quantity` AFTER decrement. This is the
   correct remaining quantity Godot should update `InventoryItem.quantity` to after 200 response.
5. **`PlantRequest.FlowerTemplateId` is a string** (Guid validated by FluentValidation). Godot sends
   the UUID string as-is.
6. **Harvest returns `NewCurrencyTotal`** — Godot should use this to update UserManager currency
   without a second profile fetch.
7. **`GardenService.parse_planted_flower()` already exists** in Godot's `services/GardenService.gd`.
   It can be reused to parse the `updatedPlot.plantedFlower` from care and plant responses.

---

## Open Questions for /ck:plan

1. **Pesticide XP vs Fertilizer XP:** Currently both have `ReceivedExp` defined per-item in DB.
   Godot's local mock treats fertilize and pesticide both as +50 XP. After BE integration, XP comes
   from `careItem.Item.ReceivedExp` (returned inside `updatedPlot.plantedFlower.currentXp`). No
   separate question — BE already handles this correctly per item type.

2. **HTTP status when item quantity = 0:** BE returns `400` with error `Constant.Error.InsufficientItem`
   when `careItem?.Item == null` (item not in inventory or qty = 0). Godot should treat 400 as a
   rollback trigger, and show a "no items left" UI hint rather than a generic error.

3. **Should `pesticide()` be a separate GardenManager method or merged into `care()`?**
   Currently water/fertilize/pesticide are 3 separate methods, each with their own TODO comment.
   They are nearly identical. Consider a single `_care_action(plot_id, action_value)` internal
   method to avoid triple-duplicating the optimistic+HTTP+rollback pattern.

4. **What happens to `LastWateredAt` etc. after cooldown removal?** BE still sets them in `CommitAsync`.
   They appear in `PlantedFlowerDto` returned to Godot. GardenService already parses `last_watered_at`.
   These timestamps become inert from a game-logic perspective but remain visible in the domain object.
   No action needed.

5. **Network timeout handling:** `_http_garden` timeout is 10s. For write ops (plant/care/harvest),
   a timeout should also rollback. The `HTTPRequest.request_completed` signal fires with
   `http_result = RESULT_CONNECTION_ERROR` or `RESULT_TIMEOUT` — both handled by the same error branch.

---

## Top Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| BE cooldown check blocks care even with items in inventory | HIGH | Blocks care feature | Remove cooldown check from `CareForFlowerAsync` in BE (single if-block deletion) |
| Double-tap race during in-flight request corrupts plot state | MEDIUM | Data inconsistency | `is_pending_sync` guard already in place — verify no code path clears it prematurely |
| Rollback restores wrong item (wrong ref_id) | MEDIUM | Inventory corruption | Capture `item.id` before consume; restore by direct id lookup, not ref_id |
| BE `DeleteInventoryItem` called when qty=0 causes 400 on next care (item gone, not qty=0) | MEDIUM | Care broken after last item consumed | Both conditions (`careItem == null` and `qty <= 0`) already return same 400 — client guard (qty == 0 check before POST) handles this |
| `UserManager.update_currency` not implemented yet | LOW | Currency not updated after harvest | Add method to UserManager as part of this feature |
| `is_pending_sync` not cleared on HTTP timeout (10s hang) | LOW | Plot permanently locked | Ensure rollback branch runs in all error paths including timeout result code |
