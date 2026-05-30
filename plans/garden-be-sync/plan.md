# Plan: Garden Gameplay BE Integration (Plant / Care / Harvest)
Status: 🟡 In Progress
Date: 2026-05-30
Mode: Hard

## Overview
Wire all four garden write operations (plant, water, fertilize, harvest) to their real BE endpoints,
replacing the current mock `await get_tree().process_frame` stubs with full optimistic-UI + rollback
flows. Adds atomic inventory decrement on the BE to prevent race conditions when multiple sessions
consume the same item concurrently.

## Phases
- [ ] Phase 1: BE Atomic Care — Remove cooldown gate; replace read-then-write decrement with atomic ExecuteUpdateAsync in CareForFlowerAsync (and PlantFlowerAsync) so concurrent care requests never send qty below 0
- [ ] Phase 2: Godot Helpers — Add `parse_plot()` to GardenService.gd, add `restore_item()` and `remove_harvest_product()` to InventoryManager.gd, add `update_currency()` to UserManager.gd — all prerequisite helpers for the write-op rollback paths
- [ ] Phase 3: GardenManager Write Ops — Replace stub water/fertilize/pesticide/plant/harvest with real HTTP POST flows using three dedicated HTTPRequest nodes, optimistic mutation, snapshot-based rollback, and authoritative BE response overwrite

## Research Summary

**Primary approach (chosen):** Per-plot `is_pending_sync` mutex + three dedicated HTTPRequest nodes
(`_http_care`, `_http_plant`, `_http_harvest`) — avoids node multiplexing complexity. Each write
method captures a deep-copy snapshot of the Plot AND the raw item quantity integer BEFORE any local
mutation. On BE failure the snapshot values are written back field-by-field (not `plot = snapshot`,
because `plot` is a reference inside `_plots`). `InventoryManager.restore_item()` takes the exact
snapshot qty, not a delta, to handle drift from concurrent sessions.

**BE atomic decrement (chosen):** `DecrementQuantityIfPositiveAsync` via EF Core `ExecuteUpdateAsync`
with `WHERE Quantity > 0`. Returns rows-affected; 0 rows → 400 InsufficientItem. Replaces the
current `careItem.Quantity--` read-then-write pattern inside the transaction. Same fix applies
to `PlantFlowerAsync` (`seedItem.Quantity--`). After `ExecuteUpdateAsync` the tracked entity qty
is stale — subtract 1 from the in-memory value manually before computing `RemainingQuantity`.

**Cooldown removal (chosen):** Delete the `if (lastCareAt.HasValue)` block from
`CareForFlowerAsync`. Timestamps remain written (analytics). No migration needed.

## Dependencies
- `Plot.deep_copy()` — already exists in `domain/Plot.gd`
- `PlantedFlower.deep_copy()` — already exists (used by Plot.deep_copy)
- `GardenService.parse_planted_flower()` — already exists; reused by care response parsing
- BE repo at `d:\WorkWithCorn\eco-backend\` must be running locally for `use_mock = false` testing
- `HttpHelper.unwrap_envelope()` — already exists and used by all existing HTTP paths

## Risks
- HIGH: `_http_care` is a single node — two plants on different plots can fire care concurrently, but a single HTTPRequest node can only handle one in-flight request. Mitigation: per-plot `is_pending_sync` ensures only one care fires at a time globally for care actions; document the limitation. If multi-plot concurrent care is needed later, switch to per-plot dynamic HTTPRequest nodes.
- MEDIUM: After `ExecuteUpdateAsync`, the EF tracked entity's `Quantity` field is stale. If the code reads `careItem.Quantity` after the atomic op, it returns the pre-decrement value. Mitigation: manually subtract 1 from `careItem.Quantity` in memory immediately after the `ExecuteUpdateAsync` call.
- MEDIUM: `harvest()` rollback must restore `current_plant` reference from the snapshot flower — `plot.plant(snapshot_flower)` is correct, but `snapshot_flower` is a deep-copy so its `id` is preserved and will re-appear correctly in UI. Mitigation: verify `deep_copy()` preserves `id` field (it does — confirmed in source).
- LOW: `UserManager._on_harvest_completed` currently adds local XP on every `harvest_completed` signal. After BE wiring, `harvest_completed` fires optimistically before BE confirms. If BE fails, the signal already fired and XP was added. Mitigation: Phase 3 documents that `harvest_completed` must only fire after BE 200 response (move emit from optimistic to success branch).
