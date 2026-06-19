# Plan: Admin-managed daily task rewards
Status: 🟢 Implemented (pending simplify + finalize)
Date: 2026-06-19
Mode: Fast

## Overview
Add two admin-only endpoints (`GET /api/admin/daily-tasks`, `PATCH /api/admin/daily-tasks/{id}/reward`) to `eco-backend` so an admin can view and tune the 4 reward fields on `DailyTaskDefinition` rows without touching task content or redeploying. No migration needed — reuses existing entity columns.

## Phases
- [x] Phase 1: Domain & repository — `GetAllTaskDefinitionsAsync` (incl. inactive) on `IDailyTaskRepository`/`DailyTaskRepository`, item-existence check path via `IUnitOfWork.Items`
- [x] Phase 2: Application layer — `DailyTaskAdminDto`, `UpdateDailyTaskRewardRequest` DTOs + `GetAdminTaskListAsync`/`UpdateTaskRewardAsync` on `IDailyTaskService`/`DailyTaskService` with FR-03 validation
- [x] Phase 3: API layer — `AdminDailyTasksController.cs` exposing the two routes, role-gated, wired to `IDailyTaskService`

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-19 22:05
**Phase in progress:** done
**Status:** All 3 phases complete + post-cook amendment. `dotnet build` succeeded for both `Application` and `API` projects (0 errors, 0 warnings). Server startup verified live (port 5285): no duplicate-route exceptions, controller discovered correctly, DB connects and seeds normally. Live curl smoke test (login + GET/PATCH) was skipped per user choice (privacy hook flagged login curl). First commit (reward-only) made locally, not pushed. Then user requested scope amendment: also allow editing `Target` — see spec.md "Amendment (2026-06-19)". Implemented: route renamed `/reward` → `/config`, DTO/validator/service method renamed accordingly, `Target > 0` validation added. Build re-verified green. **User said not to commit this round** — changes are implemented but left uncommitted.

### Decisions made this session
- Verified `IGenericRepository.GetByIdAsync(Guid)` signature matches the `_unitOfWork.Items.GetByIdAsync(request.RewardItemId.Value)` call used for item-existence validation.
- `AdminDailyTasksController` mirrors `AdminRewardTierController` exactly: `[Authorize(Roles = $"{Constant.Roles.Admin},{Constant.Roles.SuperAdmin}")]`, single-service constructor injection, `StatusCode(error.Code ?? 400, error)` pattern.
- Skipped live HTTP smoke test (login JWT + curl) after a privacy hook blocked the login command; build success + clean server startup log stand in as verification.
- Target moved from immutable "content" to editable "config" per explicit user request after reviewing the live daily-task UI — renamed endpoint to `/config` (recommended option, since no FE is built against `/reward` yet) rather than bolting Target onto the old route name or adding a second endpoint.

### Next immediate action
Awaiting user's go-ahead to commit the `/config` amendment (currently uncommitted in `D:\GitHub\eco-backend`). First commit (reward-only) is already made locally on `feat/maintain-v1`, not yet pushed.

## Research Summary
N/A (Fast mode). Pattern mirrored directly from `AdminRewardTierController.cs` + `RewardTierConfigService.cs` (read in full before writing phases): controller takes one `_service` interface, GET returns `ApiResponse<List<T>>` directly via `Ok(...)`, PATCH returns `(ApiResponse<T>? Success, ApiError? Error)` tuple with `StatusCode(error.Code ?? 400, error)` on failure. `IDailyTaskRepository` currently only exposes `GetActiveTaskDefinitionsAsync` (filters `IsActive && !IsDeleted`) and `GetDefinitionByIdAsync` (same filter) — both wrong for admin use since they hide inactive rows by design, confirming the need for a new unfiltered method rather than reusing existing ones. `IUnitOfWork.Items` (`IItemRepository : IGenericRepository<Item>`) already exposes `GetByIdAsync(Guid id)` — sufficient for the existence check, no new repository method needed there. `ClaimTaskAsync` in `DailyTaskService.cs:54-110` reads `taskDef.RewardCurrency`/`RewardXP`/`RewardItemId`/`RewardItemQty` live from the definition at claim time (not a snapshot), which satisfies FR-05/Success Criteria #4 automatically — no code change needed for that requirement.

## Dependencies
None — no new migration, no new external service, reuses `AppDbContext`/`IUnitOfWork`/existing JWT role claims. `IDailyTaskRepository` and `IDailyTaskService` are already registered in `API/Program.cs` DI container (lines 185-186); adding methods to existing interfaces requires no new DI registration. The new controller's constructor injection of `IDailyTaskService` resolves automatically.

## Risks
- LOW: Route collision with existing `api/daily-tasks` player endpoint (`DailyTasksController.cs`) — mitigated by using distinct path `api/admin/daily-tasks` and a separate controller class, matching the existing `AdminRewardTierController` vs `RewardTierController`-style split used elsewhere.
- LOW: `RewardItemQty` left stale at a positive value in DB when `RewardItemId` is cleared via a future direct DB edit (outside this API) — out of scope per spec; this API always forces `RewardItemQty = 0` when `RewardItemId` is null in the request, per FR-03.
- LOW: Existing `GetActiveTaskDefinitionsAsync`/`GetDefinitionByIdAsync` filtered queries are untouched by this change (additive only), so player-facing `DailyTasksController` behavior is unaffected — verified by reading `DailyTaskService.cs` call sites before editing.

## Test Flag
Default (standard test coverage expected per existing repo conventions; no TDD section, no skip-test note beyond standard).
