# Plan: Deco Placement System
Status: ✅ Complete
Date: 2026-06-07
Mode: Hard

## Overview
Delivers end-to-end decoration placement for garden and school scenes: players drag purchased decos from inventory onto scene backgrounds, reposition them in Edit Mode, and recall them to inventory — all persisted per-user in the database across sessions.

## Phases
- [x] Phase 1: BE Domain & Migration — New `UserDecoPlacement` entity, repository interface, EF Core DbSet, and migration
- [x] Phase 2: BE Application Layer — DTOs, `IDecoPlacementService`, `DecoPlacementService` with all 4 operations and quantity guard
- [x] Phase 3: BE API Layer — `DecoPlacementController` (4 endpoints), FluentValidation, DI wiring
- [x] Phase 4: GD Domain & Services — `DecoPlacement.gd` domain class, `DecoService` interface, Mock + Real implementations
- [x] Phase 5: GD DecoManager Autoload — Signals, edit_mode state, init/place/batch-move/recall with optimistic UI pattern
- [x] Phase 6: GD Scenes Integration — `DecoNode.tscn/.gd`, DecoLayer in GardenScene/SchoolScene, HUD Edit Mode toggle + Save button

## Research Summary
Architecture decisions locked before planning:

- **Tap vs drag:** Re-use `InputEventScreenTouch` / `InputEventScreenDrag` pattern already in `GardenScene.gd`. Drag threshold = 12–16px; tap = no drag + elapsed < 300ms. No new input system needed.
- **Hit detection:** `Area2D + CollisionShape2D` on each `DecoNode` (mirrors `Portal.tscn` pattern). No manual rect math.
- **Z-order:** `DecoLayer` is a plain `Node2D` (z_index=3) inside the scene tree — NOT a CanvasLayer. Above background, below HUD.
- **BE FK:** `UserDecoPlacement.InventoryItemId` → FK to `InventoryItem.Id`. One FK gives user link + decor link; no redundant UserId column needed at the placement level.
- **BE coordinates:** Separate `float PositionX, PositionY` columns. EF Core `HasColumnType("REAL")`. Transmitted as JSON float.
- **Recall:** Hard delete `UserDecoPlacement` + increment `InventoryItem.Quantity` in one `IUnitOfWork` transaction.
- **Batch save:** `PATCH /api/deco-placements/batch-move` — EF Core `SaveChangesAsync()` batches all UPDATEs in a single transaction.
- **Async spawn:** `await DecoService.get_placements_async(scene_name)` in `_ready`; spawn `DecoNode` children in the callback.
- **DecoManager load order:** Registered after `WeatherManager` in project.godot (spec says after FocusManager; research confirms WeatherManager is the last existing autoload).

## Dependencies
- eco-backend PostgreSQL DB accessible for EF Core migration run
- `InventoryItem.cs` already has `DecorId` (FK) and `Quantity` — no changes to that entity needed
- `ItemIconRegistry.gd` autoload resolves textures by **slug key** (not HTTP URL) — `DecoPlacementDto` must include a `decor_slug` field so `DecoNode` can look up the local texture correctly
- Purchase flow guarantees `InventoryItem` with `DecorId` exists before placement
- Phase order must be strictly: Phase 1 (BE domain) → Phase 2 (BE app) → Phase 3 (BE API) → Phase 4 (GD domain/services) → Phase 5 (GD autoload) → Phase 6 (GD scenes)

## Risks
- HIGH: Place and recall both mutate `InventoryItem.Quantity` — must be inside the same `IUnitOfWork.CommitAsync()` as the placement create/delete, or a partial failure leaves quantity out of sync. Test with a forced DB error in staging.
- HIGH: `DecoManager` spawns nodes in `_ready` via `await` — if `placements_loaded` fires before the scene tree is fully ready, child nodes may not attach. Guard with `await get_tree().process_frame` before spawning.
- HIGH: Batch-move sends all DecoNode positions on Save — if a DecoNode was never dragged its position is still included. Backend must accept no-op updates gracefully (UPDATE where new position = old position is harmless but wastes bandwidth; acceptable for v1).
- MEDIUM: EF Core migration adds a new table and FK — run on dev DB first, verify FK constraint does not break existing `InventoryItem` delete paths.
- MEDIUM: `Area2D` tap vs drag disambiguation in edit mode — if user intends to drag but releases within threshold, it fires a tap (recall). Confirm threshold (12–16px) with UX before shipping.
- MEDIUM: `ItemIconRegistry` must already have the deco image URL loaded before `DecoNode` tries to display the sprite — ensure `DecoManager.init_scene` awaits registry readiness or handles missing texture gracefully.
- LOW: z_index=3 on DecoLayer places decos above background and plots but verify it stays below HUD CanvasLayer (HUD is typically CanvasLayer layer=1, which is always above any Node2D z_index).
- LOW: Boundary clamping uses background Sprite2D rect — if background is resized for different screen ratios, clamping rect must be recalculated at runtime, not hardcoded.
- NOTED: `SceneName` is stored as a raw string in the entity. FluentValidation guards the API layer, but no DB-level CHECK constraint enforces `garden|school`. If a future scene is added, the validator must be updated or placements for the new scene will be rejected. Consider an enum conversion in a future migration.
- NOTED: `MockDecoService` hardcoded placements use fake Guids that won't match real inventory item IDs on the backend. Integration testing must switch to `RealDecoService` against a seeded DB — mock-only testing gives false confidence that the full place→display→recall loop works.
