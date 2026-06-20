# Phase 1: Domain & Repository — full-list query + item-existence check path

**Layer:** Domain → Infrastructure (no Application/API changes in this phase)

**Satisfies:** P1 story #1 (admin needs to see ALL task definitions including inactive — current repo methods filter to active-only, which is wrong for this use case).

## Requirements
Admin-facing reads must return every `DailyTaskDefinition` row (active and inactive), unlike the player-facing `GetActiveTaskDefinitionsAsync` which filters `IsActive == true`. This phase adds the missing repository capability; no entity or migration changes (FR-04 — columns already exist).

## Files

| File | Layer | Change |
|---|---|---|
| `D:\GitHub\eco-backend\Application\Interfaces\IDailyTaskRepository.cs` | Application (interface) | Add method signature `Task<List<DailyTaskDefinition>> GetAllTaskDefinitionsAsync();` |
| `D:\GitHub\eco-backend\Infrastructure\Repositories\DailyTaskRepository.cs` | Infrastructure | Implement `GetAllTaskDefinitionsAsync()` |

No changes to `Domain/Entities/DailyTaskDefinition.cs` (FR-04 — entity already has all 4 reward columns + `IsActive`).
No changes to `IUnitOfWork.cs` — `IUnitOfWork.Items.GetByIdAsync(Guid id)` (from `IGenericRepository<Item>`) already exists and is sufficient for the item-existence check used in Phase 2; confirmed by reading `Domain/Repositories/IItemRepository.cs` and `Domain/Repositories/IGenericRepository.cs`.

## Steps

1. In `IDailyTaskRepository.cs`, add a new method signature directly below `GetActiveTaskDefinitionsAsync`:
   ```csharp
   Task<List<DailyTaskDefinition>> GetAllTaskDefinitionsAsync();
   ```

2. In `DailyTaskRepository.cs`, implement it directly below `GetActiveTaskDefinitionsAsync`, excluding only soft-deleted rows (admin still needs to see inactive-but-not-deleted rows, but never deleted ones):
   ```csharp
   public Task<List<DailyTaskDefinition>> GetAllTaskDefinitionsAsync()
       => _db.DailyTaskDefinitions
             .Where(t => !t.IsDeleted)
             .ToListAsync();
   ```

3. Do not modify `GetActiveTaskDefinitionsAsync` or `GetDefinitionByIdAsync` — both are used by the live player-facing `DailyTasksController`/`ClaimTaskAsync` flow and must keep their `IsActive && !IsDeleted` filter unchanged.

4. Verify no other call site in the codebase currently expects `GetAllTaskDefinitionsAsync` to exist (confirm this is purely additive) by searching for the method name before committing.

5. Build the `Infrastructure` and `Application` projects to confirm the new interface method and implementation compile without breaking any existing mock/stub of `IDailyTaskRepository` (check test projects for a hand-written fake implementing the interface; add the new method there too if one exists).

## Success Criteria
- `dotnet build` succeeds for `Infrastructure` and `Application` projects.
- A manual call to `GetAllTaskDefinitionsAsync()` (e.g. via a temporary debug breakpoint or quick console check) returns all 8 seeded tasks regardless of `IsActive` value, while `GetActiveTaskDefinitionsAsync()` continues to return only active ones.
- No existing test or call site referencing `IDailyTaskRepository` fails to compile after the interface addition.

## Risks
- Breaking a hand-rolled test double of `IDailyTaskRepository`: search the test project for `: IDailyTaskRepository` implementations and add the new method there before building, to avoid a compile break.
- Confusing this new method with `GetActiveTaskDefinitionsAsync` in future code: name is explicit (`GetAllTaskDefinitionsAsync` vs `GetActiveTaskDefinitionsAsync`) and a doc comment will be added above it noting "includes inactive — for admin use only, do not use in player-facing flows."
