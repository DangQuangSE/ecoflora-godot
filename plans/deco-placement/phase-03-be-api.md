# Phase 3: BE API Layer

## Layer
API (Backend — .NET 8, Clean Architecture `API/` layer)

## Requirements
Expose the four deco placement operations as authenticated REST endpoints, validated with FluentValidation, and wired into the DI container — so the Godot client can call them over HTTP with a JWT token.

## Files

| File | Action | Layer | Purpose |
|------|--------|-------|---------|
| `API/Controllers/DecoPlacementController.cs` | Create | API | 4 endpoints: POST /, GET /, PATCH /batch-move, DELETE /{id} |
| `Application/Validators/PlaceDecoRequestValidator.cs` | Create | Application | FluentValidation: InventoryItemId not empty, SceneName in {"garden","school"}, X/Y finite |
| `Application/Validators/BatchMoveDecoRequestValidator.cs` | Create | Application | FluentValidation: list not empty, each entry Id not empty, X/Y finite |
| `API/Program.cs` | Modify | API | Register `IDecoPlacementService`, `IDecoPlacementRepository`, and validators in DI |

## Steps
1. Create `DecoPlacementController` at route `api/deco-placements` with `[Authorize]` on the class. Inject `IDecoPlacementService` and extract the authenticated `UserId` from the JWT claims using the same helper pattern used by existing controllers (e.g., `GardenController`).
2. Implement `POST /` — validate `PlaceDecoRequest` with FluentValidation, pass `InventoryItemId`, `SceneName`, `X`, `Y`, and the resolved `UserId` to `IDecoPlacementService.PlaceAsync`. Return `201 Created` with the new `DecoPlacementDto` on success, `400` on quantity error.
3. Implement `GET /?scene={scene}` — validate that `scene` is one of `{"garden","school"}` (inline or via a simple model-binding check), delegate to `IDecoPlacementService.GetBySceneAsync(userId, scene)`, return `200` with the list. Return `400` for unknown scene value.
4. Implement `PATCH /batch-move` — validate `BatchMoveDecoRequest`, delegate to `IDecoPlacementService.BatchMoveAsync(userId, request)`. Return `200` with `BatchMovedSuccessfully` message on success, `404` if any placement id is not found for this user.
5. Implement `DELETE /{id}` — parse the `id` as Guid, delegate to `IDecoPlacementService.RecallAsync(userId, id)`. Return `200` with `RecalledSuccessfully` on success, `404` if placement not found.
6. Create `PlaceDecoRequestValidator` (FluentValidation): `InventoryItemId` must not be empty Guid; `SceneName` must be `"garden"` or `"school"`; `PositionX` and `PositionY` must be finite floats (not NaN or Infinity).
7. Create `BatchMoveDecoRequestValidator`: the `Entries` list must not be null or empty; each `BatchMoveEntry` must have a non-empty `Id`, and finite `X`/`Y` values.
8. Register `IDecoPlacementRepository → DecoPlacementRepository`, `IDecoPlacementService → DecoPlacementService`, and both validators in `Program.cs`. Place the registrations adjacent to the existing inventory/garden service registrations.

## Spec Coverage
- FR-02: POST / place endpoint with 400 on quantity=0
- FR-03: GET /?scene= for authenticated user
- FR-04: PATCH /batch-move one-transaction update
- FR-05: DELETE /{id} recall with 404 guard
- NFR Security: `[Authorize]` + UserId extracted from JWT claims on every endpoint
- NFR Performance: no extra query weight in GET — single join query via repository

## Done When
- `dotnet build` succeeds on the full solution
- `POST /api/deco-placements` with a valid JWT and a deco item (Quantity >= 1) returns `201` with a `DecoPlacementDto` body
- `POST /api/deco-placements` with Quantity=0 item returns `400` with `InsufficientDecorQuantity` message
- `GET /api/deco-placements?scene=garden` returns only placements belonging to the authenticated user (verify by testing with two different user JWTs)
- `PATCH /api/deco-placements/batch-move` with valid ids returns `200`; with one unknown id returns `404`
- `DELETE /api/deco-placements/{id}` returns `200` and the placement row is gone from DB; `InventoryItem.Quantity` is incremented by 1
- All four endpoints return `401 Unauthorized` when called without a JWT

## Risks
- **UserId extraction pattern:** Confirm the exact claim key used in existing controllers (e.g., `ClaimTypes.NameIdentifier` vs a custom `"userId"` claim) so `DecoPlacementController` extracts the same field and does not silently return empty result sets.
- **Scene string validation:** If `scene` query param is omitted entirely (no default), the GET endpoint must return a meaningful 400, not a 500 from a null downstream.
- **Batch endpoint ownership:** `BatchMoveAsync` must verify that each placement `Id` belongs to the requesting user — not just that the id exists in the DB. Leak check: user A cannot move user B's decos by guessing Guids.
