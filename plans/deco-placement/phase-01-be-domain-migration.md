# Phase 1: BE Domain & Migration

## Layer
Domain (Backend — .NET 8, Clean Architecture `Domain/` layer)

## Requirements
Create the `UserDecoPlacement` entity and its repository contract in the backend Domain layer, register it with EF Core, and ship a migration that adds the table and FK constraint — so all higher layers have a stable data foundation to build on.

## Files

| File | Action | Layer | Purpose |
|------|--------|-------|---------|
| `Domain/Entities/UserDecoPlacement.cs` | Create | Domain | Entity with Id, InventoryItemId FK, SceneName, PositionX, PositionY, CreatedAt |
| `Domain/Repositories/IDecoPlacementRepository.cs` | Create | Domain | Repository contract: GetByUserAndSceneAsync, AddAsync, UpdateRangeAsync, DeleteAsync |
| `Infrastructure/Data/AppDbContext.cs` | Modify | Infrastructure | Add `DbSet<UserDecoPlacement>`, configure FK and column types |
| `Infrastructure/Migrations/` | Create | Infrastructure | EF Core migration `AddDecoPlacementTable` |

## Steps
1. Define the `UserDecoPlacement` entity in `Domain/Entities/` with five data fields — `Id` (Guid), `InventoryItemId` (Guid FK), `SceneName` (string), `PositionX` (float), `PositionY` (float) — plus `CreatedAt` (DateTime UTC) and a navigation property back to `InventoryItem`. Keep this class dependency-free (no EF Core attributes, no application imports).
2. Define `IDecoPlacementRepository` in `Domain/Repositories/` with four method signatures: fetch all placements by user and scene (joins through `InventoryItem → UserInventory → UserId`), add a single placement, update a batch of placements, and delete a single placement by id. Match the async signature style of the existing repository interfaces in the project.
3. In `AppDbContext`, add `DbSet<UserDecoPlacement>` and an `OnModelCreating` configuration block that: sets the FK to `InventoryItem` with **`OnDelete(DeleteBehavior.Restrict)`** (not Cascade — prevents silent placement deletion when inventory is purged), maps `PositionX` and `PositionY` to `HasColumnType("REAL")`, and adds an index on `InventoryItemId` + `SceneName` for the GET query path.
4. Extend `IUnitOfWork` (in `Application/Interfaces/IUnitOfWork.cs`) with a new property `IDecoPlacementRepository DecoPlacemens { get; }`, and add the corresponding property implementation in `UnitOfWork` (in `Infrastructure/`) injecting `DecoPlacementRepository`. This is required before `DecoPlacementService` can compile.
5. Implement `DecoPlacementRepository` in `Infrastructure/Repositories/` using `GenericRepository<UserDecoPlacement>` as the base. The custom `GetByUserAndSceneAsync` query **must** include `.Include(p => p.InventoryItem).ThenInclude(i => i.Decor)` so `DecorImageUrl` is populated without a lazy-load exception. Filter by `InventoryItem.UserInventory.UserId == userId` in the same query.
6. Run `dotnet ef migrations add AddDecoPlacementTable` from the API project and review the generated migration file — confirm the FK constraint points to `InventoryItems` and both float columns appear with type `REAL`. Apply with `dotnet ef database update` on the dev database.
7. Verify the table and FK exist in the dev database using a DB client, then check that no existing `InventoryItem` or `UserInventory` rows are broken by the new FK.

## Spec Coverage
- FR-01: `UserDecoPlacement` entity with all required fields
- NFR Consistency: FK ensures every placement row is tied to a real inventory item

## Done When
- `dotnet build` succeeds with zero errors on the `Domain` and `Infrastructure` projects
- `dotnet ef database update` runs without error on the dev database
- The `UserDecoPlacement` table exists in the dev DB with columns: `Id`, `InventoryItemId` (FK → `InventoryItems.Id`), `SceneName`, `PositionX` (REAL), `PositionY` (REAL), `CreatedAt`
- Dropping a referenced `InventoryItem` row (or running FK check) demonstrates the constraint is active

## Risks
- **FK cascade on InventoryItem delete:** If the project deletes `InventoryItem` rows on quantity=0, a cascade delete will silently remove all placements for that item. Check the existing delete path and set `OnDelete(DeleteBehavior.Restrict)` if needed, or handle this explicitly in the recall flow.
- **Migration rollback:** If the migration is applied to a production-like DB and the FK fails due to orphaned data, the migration will abort mid-way. Verify no orphaned `InventoryItem` rows exist before applying.
