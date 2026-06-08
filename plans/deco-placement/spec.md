# Spec: Deco Placement System

**Date:** 2026-06-07
**Status:** Draft

---

## Problem Statement

Users can purchase decoration items but cannot use them — no placement UI or backend exists. This feature lets players freely place decos anywhere on garden/school scene backgrounds, with positions saved persistently per user.

---

## User Stories

- **[P1]** As a player, I want to drag a deco from my inventory onto the garden/school background so that I can decorate my space.
  Accepted when: deco appears at drop position in the scene, inventory quantity decreases by 1, placement is saved to BE.

- **[P1]** As a player, I want to enter Edit Mode, drag placed decos to new positions, then press Save so that my layout is updated.
  Accepted when: after Save, a single PATCH request updates all moved positions; decos render at new positions on next scene load.

- **[P1]** As a player, I want to tap a placed deco to recall it back to inventory so that I can reuse it elsewhere.
  Accepted when: deco node removed from scene, inventory quantity +1, placement record deleted from BE.

- **[P1]** As a player, I want my placed decos to be visible when I re-enter the scene so that my decoration persists between sessions.
  Accepted when: on scene load, all placements fetched from BE and rendered at correct positions.

- **[P2]** As a player, I want placed decos to render with correct z-order (newer on top) so that overlapping decos look intentional.
  Accepted when: most recently placed deco always renders above older ones.

- **[P3]** _(out of scope — layer reordering by user)_
- **[P3]** _(out of scope — deco placement in scenes beyond garden + school)_

---

## Functional Requirements

1. **FR-01:** New BE entity `UserDecoPlacement` stores: Id (Guid), UserId, DecorId, SceneName (enum: `garden` | `school`), XPosition (float, 1 decimal), YPosition (float, 1 decimal), CreatedAt.
2. **FR-02:** `POST /api/deco-placements` — place deco; atomically deducts 1 from `InventoryItem.Quantity` and creates `UserDecoPlacement`. Returns 400 if quantity = 0.
3. **FR-03:** `GET /api/deco-placements?scene={scene}` — returns all placements for authenticated user in given scene.
4. **FR-04:** `PATCH /api/deco-placements/batch-move` — accepts array of `{id, x, y}`; updates positions in one transaction. Called on Edit Mode Save.
5. **FR-05:** `DELETE /api/deco-placements/{id}` — recall; atomically increments `InventoryItem.Quantity` by 1 and deletes placement.
6. **FR-06:** New Godot autoload `DecoManager` — registered after `FocusManager` in project.godot. Handles fetch, spawn, edit mode state, and batch save.
7. **FR-07:** Each scene (GardenScene, SchoolScene) calls `DecoManager.init_scene(scene_name)` on `_ready`. DecoManager spawns `DecoNode` (Sprite2D) for each fetched placement as child of a `DecoLayer` CanvasLayer.
8. **FR-08:** Edit Mode toggled via HUD button. In Edit Mode: decos show drag handles, inventory panel hidden. Outside Edit Mode: tap placed deco → confirm dialog → recall.
9. **FR-09:** Placement boundary enforced client-side to scene background rect (no off-screen placement).
10. **FR-10:** Deco asset resolved via `ItemIconRegistry` (already handles deco image URLs).

---

## Non-Functional Requirements

- **Performance:** `GET /api/deco-placements` responds in < 200ms for up to 50 placements per user per scene.
- **Consistency:** Place and recall are single DB transactions — no partial state.
- **Coordinates:** XPosition/YPosition stored as `FLOAT` (1 decimal precision) in DB; transmitted as JSON float.
- **Security:** All endpoints require authenticated user JWT; users can only read/write their own placements.

---

## Success Criteria

- [ ] Place a deco → appears in scene, inventory -1, persists after scene reload.
- [ ] Edit Mode → drag 3 decos → Save → re-enter scene → all 3 at new positions.
- [ ] Recall deco → removed from scene, inventory +1, gone after scene reload.
- [ ] 0 quantity deco → place attempt returns 400, no node spawned.
- [ ] `GET /api/deco-placements` returns only placements for the requesting user (no data leak).

---

## Out of Scope

- Layer reordering by user (z-index control)
- Deco placement outside garden and school scenes
- Collision detection between placed decos
- Deco rotation or scaling
- Undo/redo in Edit Mode

---

## Assumptions

- `ItemIconRegistry` already resolves deco image URLs from the backend `ImageUrl` field — no new asset pipeline needed.
- Scene background rect is well-defined and stable (not dynamic layout).
- `InventoryItem` with `DecorId` always exists before placement (purchase flow guarantees it).
- DecoManager loads after FocusManager — no dependency on WeatherManager.
