# Phase 3: API — AdminDailyTasksController

**Layer:** API

**Satisfies:** P1 stories #1, #2, #3 and P2 story (exposes the validated Phase 2 service methods over HTTP, role-gated per NFR Security).

## Requirements
Expose `GET /api/admin/daily-tasks` and `PATCH /api/admin/daily-tasks/{id}/reward` as `[Authorize(Roles = "Admin,SuperAdmin")]` endpoints, matching the exact response-wrapping conventions of `AdminRewardTierController`.

## Files

| File | Layer | Change |
|---|---|---|
| `D:\GitHub\eco-backend\API\Controllers\AdminDailyTasksController.cs` | API | New file |

No `Program.cs` change needed — `IDailyTaskService` is already registered (`builder.Services.AddScoped<IDailyTaskService, DailyTaskService>();`), so the new controller's constructor injection resolves automatically.

## Steps

1. Create `AdminDailyTasksController.cs` with route `[Route("api/admin/daily-tasks")]` and class-level `[Authorize(Roles = $"{Constant.Roles.Admin},{Constant.Roles.SuperAdmin}")]`, exactly matching `AdminRewardTierController`'s attribute style — confirm this route does not collide with the existing player-facing `[Route("api/daily-tasks")]` in `DailyTasksController.cs` (it does not — distinct path segment `admin`).

2. Inject `IDailyTaskService _service` via constructor (single dependency, matching `AdminRewardTierController`'s one-service pattern).

3. Implement `GET` (no route suffix, root of `api/admin/daily-tasks`):
   ```csharp
   [HttpGet]
   [ProducesResponseType(typeof(ApiResponse<List<DailyTaskAdminDto>>), 200)]
   public async Task<IActionResult> GetAll()
   {
       var response = await _service.GetAdminTaskListAsync();
       return Ok(response);
   }
   ```

4. Implement `PATCH` on `{id}/reward`:
   ```csharp
   [HttpPatch("{id}/reward")]
   [ProducesResponseType(typeof(ApiResponse<DailyTaskAdminDto>), 200)]
   [ProducesResponseType(typeof(ApiError), 400)]
   [ProducesResponseType(typeof(ApiError), 404)]
   public async Task<IActionResult> UpdateReward(Guid id, [FromBody] UpdateDailyTaskRewardRequest request)
   {
       var (success, error) = await _service.UpdateTaskRewardAsync(id, request);
       if (error != null)
           return StatusCode(error.Code ?? 400, error);
       return Ok(success);
   }
   ```

5. Add `using Application.DTOs.DailyTask;`, `using Application.Helpers;`, `using Application.Interfaces;`, `using Microsoft.AspNetCore.Authorization;`, `using Microsoft.AspNetCore.Mvc;` at the top, matching `AdminRewardTierController.cs`'s exact using-block order.

6. Build the `API` project and confirm the new controller is discovered (no duplicate route errors against `DailyTasksController` or `AdminRewardTierController`).

7. Smoke-test both endpoints with a valid Admin-role JWT (manually via REST client or curl):
   - `GET /api/admin/daily-tasks` → 200, body contains all 8 seeded tasks with reward fields and `isActive`.
   - `PATCH /api/admin/daily-tasks/{validId}/reward` with a valid body → 200, response DTO shows new values, `title`/`target`/`cycle` unchanged.
   - `PATCH /api/admin/daily-tasks/{validId}/reward` with `rewardItemId` set to a random unused GUID → 400.
   - `PATCH /api/admin/daily-tasks/{nonExistentId}/reward` → 404.
   - Either endpoint called with a Player-role JWT (or no JWT) → 401/403 (verify which one ASP.NET Core's `[Authorize(Roles=...)]` returns in this codebase by testing against the existing `AdminRewardTierController` for comparison).

## Success Criteria
- `dotnet build` succeeds for `API` project with no route-conflict errors.
- All 4 Success Criteria bullets from `spec.md` pass manually: GET lists all 8 seeded tasks; PATCH changes reward values while leaving title/target/cycle unchanged (verified by a follow-up GET); PATCH with unknown `rewardItemId` returns 400 and leaves the row unchanged; a task edited mid-period before claim grants the new reward values at claim time (verify by calling `POST /api/daily-tasks/{id}/claim` after a PATCH and checking the returned currency/XP delta matches the new values, not the old ones).
- Both routes reject requests without `Admin`/`SuperAdmin` role.

## Risks
- Route ambiguity between `api/admin/daily-tasks/{id}/reward` (PATCH) and any future admin route under the same prefix: low risk now since this is the only admin daily-task route; document the prefix choice (`api/admin/daily-tasks`) so future admin task endpoints (e.g. Out-of-Scope create/delete) nest under it consistently.
- `[FromBody] UpdateDailyTaskRewardRequest` deserialization defaulting `RewardItemId` to `null` when omitted vs. explicitly sent as `null` — both cases must behave identically (clear the item, force qty to 0); confirm via a smoke test sending the field as JSON `null` explicitly.
