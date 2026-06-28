# Phase 1: CharacterConfig Entity

## Requirements

Create CharacterConfig domain entity, EF Core configuration, repository interface + implementation, IUnitOfWork registration, migration with seed data.

## Steps

1. Create `Domain/Entities/CharacterConfig.cs` extending `BaseEntity`:
   - `Id: Guid`
   - `CharacterIndex: int` (unique)
   - `Name: string`
   - `Price: int`
   - `IsActive: bool`
   - (No ImageUrl — Godot hardcodes sprite by index, DB field out of scope per spec)
   - Add `[ConcurrencyCheck]` attribute on `Price` field for optimistic concurrency (PostgreSQL → EF Core maps to xmin system column via `UseXminAsConcurrencyToken()` in OnModelCreating, or add a `byte[] RowVersion` timestamp column).

2. Create `Domain/Repositories/ICharacterConfigRepository.cs` extending `IBaseRepository<CharacterConfig>`:
   - `Task<CharacterConfig?> GetByCharacterIndexAsync(int charIdx)`
   - Follow `IItemRepository` pattern.

3. Create `Infrastructure/Repositories/CharacterConfigRepository.cs` implementing `ICharacterConfigRepository`.
   - Follow `ItemRepository` pattern.

4. Add to `Application/Interfaces/IUnitOfWork.cs`:
   ```csharp
   ICharacterConfigRepository CharacterConfigs { get; }
   ```
   Add implementation in `Infrastructure/Repositories/UnitOfWork.cs`.

5. Add `DbSet<CharacterConfig> CharacterConfigs` to `AppDbContext`.

6. In `AppDbContext.OnModelCreating`, add:
   - Unique index on `CharacterIndex`
   - Global query filter: `modelBuilder.Entity<CharacterConfig>().HasQueryFilter(cc => !cc.IsDeleted);`
   - Seed data via `.HasData()` (EF Core auto-idempotent):
     ```csharp
     modelBuilder.Entity<CharacterConfig>().HasData(
         new CharacterConfig { Id = Guid.Parse("...fixed-guid-0..."), CharacterIndex = 0, Name = "Lily", Price = 0,  IsActive = true },
         new CharacterConfig { Id = Guid.Parse("...fixed-guid-1..."), CharacterIndex = 1, Name = "Leo",  Price = 10000, IsActive = true }
     );
     ```
   - Use fixed GUIDs (hardcode) so migration is idempotent on repeated runs.

7. Generate EF Core migration: `Add-Migration AddCharacterConfigTable`.

8. Run migration: `Update-Database`.

9. Verify via SQL: SELECT * FROM CharacterConfigs — should return 2 rows.

## Success Criteria

- `CharacterConfigs` table exists with all columns including `ConcurrencyToken` (EF Core maps `[ConcurrencyCheck]` to xmin/rowversion or timestamp column)
- Unique constraint on `CharacterIndex` — duplicate insert throws
- `HasQueryFilter` excludes soft-deleted rows automatically — no explicit `IsDeleted` check needed in service layer
- Seed: character 0 price=0, character 1 price=10000
- `IUnitOfWork.CharacterConfigs` property compiles and resolves

## Risks

- Fixed GUIDs in seed: must be stable across environments — use the same hardcoded values in all migrations.
- [ConcurrencyCheck] requires DB provider support (PostgreSQL → xmin strategy; SQL Server → rowversion). Confirm provider before migration.
