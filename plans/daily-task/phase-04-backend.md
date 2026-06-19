# Phase 4: Backend (eco-backend — ASP.NET Core .NET 8)

## Layer
Backend only — ASP.NET Core Clean Architecture (`Domain`, `Application`, `Infrastructure`, `API` projects). All changes are in the `eco-backend` repository at `D:\GitHub\eco-backend`.

## Files

| File path | Layer | Action |
|---|---|---|
| `Domain/Entities/DailyTaskDefinition.cs` | Domain | CREATE |
| `Domain/Entities/UserTaskProgress.cs` | Domain | CREATE |
| `Domain/Enums/TaskType.cs` | Domain | CREATE |
| `Domain/Enums/TaskCycle.cs` | Domain | CREATE |
| `Application/DTOs/DailyTask/DailyTaskDto.cs` | Application | CREATE |
| `Application/DTOs/DailyTask/TaskProgressDto.cs` | Application | CREATE |
| `Application/DTOs/DailyTask/DailyTaskListResponse.cs` | Application | CREATE |
| `Application/DTOs/DailyTask/ClaimResultDto.cs` | Application | CREATE |
| `Application/Interfaces/IDailyTaskService.cs` | Application | CREATE |
| `Application/Services/DailyTaskService.cs` | Application | CREATE |
| `Infrastructure/Migrations/{timestamp}_DailyTasks.cs` | Infrastructure | CREATE (generated) |
| `Infrastructure/Data/AppDbContext.cs` | Infrastructure | MODIFY |
| `Infrastructure/Data/Seed/DailyTaskSeed.cs` | Infrastructure | CREATE |
| `API/Controllers/DailyTasksController.cs` | API | CREATE |
| `API/FluentValidation/ClaimTaskRequestValidator.cs` | API | CREATE |
| `docs/daily-task/task-stable-ids.md` | Docs | CREATE |

## Requirements
The backend exposes two authenticated endpoints — GET to return all active task definitions joined with the calling user's current-period progress (resetting stale progress inline), and POST to validate completion and grant rewards — so the Godot client can display authoritative progress on login and receive server-validated rewards on claim.

## Steps
1. Create `DailyTaskDefinition` entity in `Domain/Entities` extending `BaseEntity`. Fields: `Id` (Guid), `Title` (string), `Description` (string), `Type` (TaskType enum), `ActionSubtype` (string?, nullable — e.g. `"water"`), `Target` (int), `Cycle` (TaskCycle enum — `DAILY` or `WEEKLY`), `RewardCurrency` (int), `RewardItemId` (Guid?, nullable), `RewardItemQty` (int), `RewardXP` (int), `IsActive` (bool). Create `UserTaskProgress` entity: `Id` (Guid), `UserId` (Guid, FK to User), `TaskDefinitionId` (Guid, FK to DailyTaskDefinition), `Progress` (int), `Claimed` (bool), `PeriodStart` (DateTime UTC). Add `TaskType` and `TaskCycle` enums. Register both entities in `AppDbContext` and generate the EF Core migration.

2. Seed the 8 task definitions (5 daily + 3 weekly) via `DailyTaskSeed.cs` called from `AppDbContext.OnModelCreating` using `modelBuilder.Entity<DailyTaskDefinition>().HasData(...)`. Use stable hardcoded Guids so re-seeding is idempotent. Task definitions mirror the spec: GARDEN_CARE×water (daily, target 3), GARDEN_CARE×fertilize (daily, target 2), HARVEST (daily, target 2), FOCUS_SESSION (daily, target 1 session), ONLINE_TIME (daily, target 30 minutes), GARDEN_CARE×any (weekly, target 10), HARVEST (weekly, target 5), FOCUS_SESSION (weekly, target 3 sessions). **Reward values are baked into the `HasData` seed** (e.g., `RewardCurrency = 100`). To change them, edit the seed constants and regenerate the migration — do NOT mix with `appsettings.json` (EF Core `HasData` runs at migration time and ignores runtime config). Publish the 8 stable Guids to `docs/daily-task/task-stable-ids.md` so the Godot offline fallback uses the same IDs.

3. Implement `IDailyTaskService` interface with two methods: `GetTasksAsync(string userId) -> Task<ApiResponse<DailyTaskListResponse>>` and `ClaimTaskAsync(string userId, Guid taskId) -> Task<(ApiResponse<ClaimResultDto>? Success, ApiError? Error)>`. Implement `DailyTaskService`. In `GetTasksAsync`: load all active `DailyTaskDefinition` rows; for each, find or create the user's `UserTaskProgress` for the current period (computed as 7AM UTC+7 today for DAILY, or 7AM UTC+7 last Monday for WEEKLY). If the existing progress row has a `PeriodStart` older than the current period boundary, reset `Progress = 0`, `Claimed = false`, `PeriodStart = currentPeriodStart` inline before returning. Return a `DailyTaskListResponse` containing the task definitions list, the progress list, and a `ServerTimeUtc` field set to `DateTime.UtcNow`.

4. In `DailyTaskService.ClaimTaskAsync`: load the `DailyTaskDefinition` and the user's `UserTaskProgress` row. Reject if `Claimed == true` (409 Conflict). **Epoch guard (prevents cross-period double-claim at 7AM boundary):** call `GetCurrentPeriodStart(taskDef.Cycle, DateTime.UtcNow)` and compare against `UserTaskProgress.PeriodStart`. If they differ, the cron has already advanced the period while this request was in flight — return 400 Bad Request with body `{"error":"period_expired"}` and do not grant any reward. Cross-validate progress using a COUNT query on real action records: for `GARDEN_CARE`, count `PlantedFlower` care log records (or use the client-reported progress if no care log table exists yet — document the gap and accept client trust for EXE2). For `FOCUS_SESSION`, count `FocusSession` rows for the user with status `COMPLETED` in the current period. For `HARVEST` and `ONLINE_TIME`, trust the client's `UserTaskProgress.Progress` value (add a TODO comment for future anti-cheat). Reject with 400 if validated progress < `Target`. Open a DB transaction: grant `RewardCurrency` (add to `user.Currency`), grant `RewardXP` via `LevelHelper.ComputeLevel`, and if `RewardItemId` is set call the existing `GrantItemInTransactionAsync` pattern from `VitalityService`. Set `UserTaskProgress.Claimed = true`. Call `TryCommitAsync`; on concurrency conflict return 409.

5. Create `DailyTasksController` in `API/Controllers`. Route: `[Route("api/daily-tasks")]`, `[Authorize(Roles = Constant.Roles.Player)]`. Add `GET /` calling `IDailyTaskService.GetTasksAsync` and `POST /{taskId}/claim` calling `IDailyTaskService.ClaimTaskAsync`. Extract `userId` from the JWT claim named `"id"` (matching the pattern in `GardenController`). Register `IDailyTaskService → DailyTaskService` in the DI container (Program.cs or wherever other services are registered).

6. Add an `IHostedService` cron job (`DailyTaskResetJob`) that runs at 7:00 AM UTC+7 (00:00 UTC) as supplementary cleanup: bulk-update all `UserTaskProgress` rows whose `PeriodStart` is older than the current period boundary, resetting `Progress` and `Claimed`. This is a safety net only — the lazy-reset in the GET endpoint is the primary mechanism. Compute next-run time in the `ExecuteAsync` loop using `Task.Delay` rather than adding a heavy scheduling library.

7. Write integration smoke tests (can be a simple `.http` file or xUnit test): verify `GET /api/daily-tasks` returns 5 daily + 3 weekly tasks with `progress = 0` for a new user; verify `POST /api/daily-tasks/{id}/claim` with insufficient progress returns 400; verify a successful claim returns 200 with `newCurrencyTotal`, `newUserXP`, `newUserLevel` and marks the task `claimed = true` in a subsequent GET.

## Success Criteria
- `GET /api/daily-tasks` returns a JSON envelope with `tasks` (8 items) and `progress` (8 items) for any authenticated Player-role user
- A fresh user's progress rows show `progress: 0, claimed: false` on first GET
- After manually setting a `UserTaskProgress.Progress` to `>= target` in the DB, `POST /api/daily-tasks/{id}/claim` returns 200 and the user's currency/XP in the response reflect the reward
- Calling claim a second time on the same already-claimed task returns 409
- After the period boundary passes, the next GET call resets the progress rows inline and returns `progress: 0`
- The EF Core migration applies cleanly to a fresh database (`dotnet ef database update`)

## Risks
- Care log table does not yet exist in eco-backend (no `PlantActionLog` entity in the codebase) — COUNT-based validation for GARDEN_CARE will fall back to trusting client progress. Mitigation: add a TODO comment in `ClaimTaskAsync`; this is explicitly accepted for EXE2 per spec (out-of-scope: anti-cheat).
- `LevelHelper.ComputeLevel` is referenced in `VitalityService` but must be confirmed present in `Application/Helpers`. Mitigation: grep for it before implementation; if missing, inline the XP-to-level formula from `UserManager.gd`'s `_XP_TABLE` equivalent.
- Period boundary calculation must handle the UTC+7 offset correctly — `DateTime.UtcNow` + 7 hours, floor to 7AM of that local day, then convert back to UTC. Mitigation: extract a static `GetCurrentPeriodStart(TaskCycle cycle, DateTime utcNow) -> DateTime` helper so the logic is tested in isolation.
