# Phase 2: BE Application Layer

## Layer
Application (Backend — .NET 8, Clean Architecture `Application/` layer)

## Requirements
Define all DTOs and the `IDecoPlacementService` contract, then implement `DecoPlacementService` with the four core operations (place, get by scene, batch move, recall) — each using a single `IUnitOfWork` transaction and the quantity guard on `InventoryItem`.

## Files

| File | Action | Layer | Purpose |
|------|--------|-------|---------|
| `Application/DTOs/DecoPlacement/PlaceDecoRequest.cs` | Create | Application | Request body: InventoryItemId, SceneName, X, Y |
| `Application/DTOs/DecoPlacement/BatchMoveDecoRequest.cs` | Create | Application | Request body: List of {Id, X, Y} move entries |
| `Application/DTOs/DecoPlacement/BatchMoveEntry.cs` | Create | Application | Single entry inside BatchMoveDecoRequest |
| `Application/DTOs/DecoPlacement/DecoPlacementDto.cs` | Create | Application | Response shape: Id, InventoryItemId, DecorId, DecorImageUrl, DecorSlug, SceneName, X, Y |
| `Application/Interfaces/IDecoPlacementService.cs` | Create | Application | Contract: PlaceAsync, GetBySceneAsync, BatchMoveAsync, RecallAsync |
| `Application/Services/DecoPlacementService.cs` | Create | Application | Implements IDecoPlacementService using IDecoPlacementRepository + IUnitOfWork |
| `Application/Constants/DecoPlacementMessages.cs` | Create | Application | String constants: PlacedSuccessfully, RecalledSuccessfully, BatchMovedSuccessfully, InsufficientDecorQuantity, PlacementNotFound |

## Steps
1. Create the three DTO files under `Application/DTOs/DecoPlacement/`: `PlaceDecoRequest` (InventoryItemId, SceneName, X, Y), `BatchMoveEntry` (Id, X, Y), `BatchMoveDecoRequest` (wraps a `List<BatchMoveEntry>`), and `DecoPlacementDto` (outbound shape including `DecorImageUrl` projected from the navigation property). Match the record/class style used by existing DTOs in the project.
2. Create `DecoPlacementMessages.cs` with the five string constants. Use the same constant-class pattern as other message classes in the project.
3. Define `IDecoPlacementService` with four method signatures — return types follow the project's `(ApiResponse<T>? Success, ApiError? Error)` tuple pattern. Scene name is passed as a plain string; the service validates its value.
4. Implement `PlaceAsync` in `DecoPlacementService`: call `await _unitOfWork.BeginTransactionAsync()` first. Load the `InventoryItem` by id (scoped to the calling `userId` via `UserInventory`), return `InsufficientDecorQuantity` 400 if `Quantity < 1`. Add a `[ConcurrencyCheck]` stamp on `InventoryItem.Quantity` (or use `TryCommitAsync` with a retry/400 on `DbUpdateConcurrencyException`) to guard against concurrent place requests. Decrement `Quantity`, create a new `UserDecoPlacement` row, call `IUnitOfWork.CommitAsync()` once covering both mutations.
5. Implement `GetBySceneAsync`: delegate to `IDecoPlacementRepository.GetByUserAndSceneAsync`, project each entity to `DecoPlacementDto`. Populate `DecorImageUrl` from `InventoryItem.Decor.ImageUrl` and compute `DecorSlug` as `decor.Name.ToLower().Replace(" ", "_")` (e.g., `"Water Tower"` → `"water_tower"`) — this is the key used by Godot's `ItemIconRegistry`. Return `ApiResponse<List<DecoPlacementDto>>`.
6. Implement `BatchMoveAsync`: query `WHERE Id IN (ids) AND InventoryItem.UserInventory.UserId = userId` — any id that doesn't exist **or belongs to another user** returns `PlacementNotFound` 404 with no partial commit. Validate all ids before mutating any row. Apply new X/Y values, call `IDecoPlacementRepository.UpdateRangeAsync`, commit once.
7. Implement `RecallAsync`: call `await _unitOfWork.BeginTransactionAsync()` first. Query `WHERE Id = id AND InventoryItem.UserInventory.UserId = userId` — return 404 if missing **or if the placement belongs to another user**. Load the linked `InventoryItem`, increment `Quantity`, delete the placement, commit both in one `IUnitOfWork.CommitAsync()`. Return `RecalledSuccessfully`.
8. Register `IDecoPlacementService → DecoPlacementService` in the DI container (prepare the line for Phase 3 to drop into `Program.cs`).

## Spec Coverage
- FR-02: Place with quantity guard and atomic write
- FR-03: Get all placements for a user/scene
- FR-04: Batch move positions in one transaction
- FR-05: Recall with atomic quantity increment and placement delete
- NFR Consistency: all mutating operations use a single `CommitAsync`
- NFR Security: `GetBySceneAsync` scopes to the calling user via `IDecoPlacementRepository.GetByUserAndSceneAsync`

## Done When
- `dotnet build` succeeds on the `Application` project with zero warnings/errors
- Unit-level logic check (manual or via debugger): `PlaceAsync` with `Quantity=0` returns error tuple, not success
- `PlaceAsync` with `Quantity=1` returns success and the in-memory `Quantity` becomes 0 before `CommitAsync`
- `RecallAsync` with a valid id increments `Quantity` and removes the placement entity before `CommitAsync`
- `BatchMoveAsync` with one missing id in the list returns 404 without committing any partial update

## Risks
- **Partial batch failure:** If one id in `BatchMoveAsync` is missing, no UPDATEs should be committed. Ensure all ids are validated before calling `UpdateRangeAsync` — do not commit a partial set.
- **`CommitAsync` already called by another service:** `UpsertInventoryItemAsync` previously had an internal `CommitAsync` (fixed in currency-vitality-shop plan). Confirm the current codebase does not auto-commit inside quantity mutation helpers before adding the outer `CommitAsync` here.
- **Navigation chain for `DecorImageUrl`:** Projecting `InventoryItem.Decor.ImageUrl` requires the EF Core query to include the `Decor` navigation. Confirm the join is explicit (`.Include(i => i.Decor)`) or the repository method already loads it.
