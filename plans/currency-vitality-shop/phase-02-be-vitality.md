# Phase 2: BE Vitality Endpoints

**Codebase:** eco-backend (`d:\WorkWithCorn\eco-backend\`)

## Requirements
Expose two authenticated endpoints that let the Godot client check vitality readiness and claim a random reward once per 6-hour window. The server is the sole source of truth for cooldown enforcement and reward generation.

## Steps
1. Create `Application/DTOs/Vitality/VitalityStatusDto.cs` (fields: `IsReady bool`, `SecondsUntilReady int`, `LastClaimUtc DateTime?`) and `VitalityClaimResultDto.cs` (fields: `RewardType string`, `RewardAmount int`, `RewardItemId string?`, `NewCurrencyTotal int`, `NewUserXP int`, `NewUserLevel int`). Add corresponding success/error constants to `Constant.cs`.
2. Create `Application/Interfaces/IVitalityService.cs` with two method signatures: `GetStatusAsync(string userId)` returning `(ApiResponse<VitalityStatusDto>? Success, ApiError? Error)` and `ClaimAsync(string userId)` returning the same tuple shape for `VitalityClaimResultDto`.
3. Implement `Application/Services/VitalityService.cs`: `GetStatusAsync` loads the user, computes `SecondsUntilReady = max(0, (VitalityReadyAt - UtcNow).TotalSeconds)` and sets `IsReady = SecondsUntilReady == 0`. `ClaimAsync` re-checks the cooldown server-side (reject with 400 if not ready), picks the reward via a seeded `Random` using the configured probability table (40% XP +200, 40% item, 20% currency +5), applies the reward inside `BeginTransactionAsync`/`CommitAsync`, sets `user.VitalityReadyAt = UtcNow + 6h`, and returns the claim result.
4. Handle the item reward branch (40%): randomly select between granting 2x water or 1x fertilizer. **Do NOT call `IInventoryService.GrantItemAsync` directly** — it calls `CommitAsync()` internally (confirmed at `InventoryService.cs` line ~109), which will commit and dispose the outer transaction. Instead, extract (or call directly) a lower-level `_unitOfWork.Inventories.UpsertItemAsync` call that only mutates in-memory state without committing. The single `CommitAsync` at the end of `ClaimAsync` is the only commit. If `UpsertItemAsync` on the repository is not available without a commit, the prerequisite refactor in Phase 3 Step 1 (removing the internal commit from `BuyItemAsync`'s inventory upsert path) should also extract a shared `UpsertInventoryItemInternalAsync` method — reuse that same method here.
5. Create `API/Controllers/VitalityController.cs` with `[Route("api/vitality")]`, `[Authorize(Roles = Constant.Roles.Player)]`. Add `GET /status` mapped to `GetStatusAsync` and `POST /claim` mapped to `ClaimAsync`. Extract `userId` from the JWT claim `"id"` using the same pattern as `GardenController`.
6. Register `IVitalityService` → `VitalityService` in `Program.cs` (or the DI extension method file) alongside the other service registrations. Confirm the `GrantItemAsync` dependency is already registered (`IInventoryService`).
7. Test manually via Swagger: call `GET /api/vitality/status` on a fresh account (expect `isReady: true`, `secondsUntilReady: 0`). Call `POST /api/vitality/claim` (expect reward fields populated and `user.VitalityReadyAt` set to ~6h from now in DB). Call `POST /api/vitality/claim` again immediately (expect HTTP 400 with cooldown error message).

## Success Criteria
- `GET /api/vitality/status` returns HTTP 200 with `isReady: true` for a user whose `VitalityReadyAt` is null or in the past.
- `GET /api/vitality/status` returns `isReady: false` and a positive `secondsUntilReady` within 1s of a recent claim.
- `POST /api/vitality/claim` returns HTTP 200 with a populated `rewardType`, `rewardAmount`, and correct updated totals (`newCurrencyTotal`, `newUserXP`, `newUserLevel`).
- A second `POST /api/vitality/claim` within 6h returns HTTP 400.
- After an XP reward claim: `GET /api/auth/profile` shows `currentXp` increased by 200.
- After an item reward claim: `GET /api/inventory` shows the granted item count increased.
- After a currency reward claim: `GET /api/auth/profile` shows `currency` increased by 5.

## Risks
- **[CRITICAL — addressed in Step 4]** Item grant must NOT use `GrantItemAsync` (commits internally). Use the lower-level repository upsert method within the outer transaction. If `UpsertInventoryItemInternalAsync` does not exist yet, create it as part of this phase before wiring up the reward branch.
- **[Concurrency]** `VitalityReadyAt` is marked `[ConcurrencyCheck]` (Phase 1). If two simultaneous claim requests both pass the cooldown check before either commits, the second writer will throw `DbUpdateConcurrencyException`. Catch this in `ClaimAsync` and return HTTP 409 (already claimed). The Godot `_claim_in_flight` guard prevents the common case but does not protect against multi-device scenarios.
- Random reward uses server-side `Random` — ensure a single static instance is not shared across concurrent requests (use `new Random()` per call or inject `IRandomService` for testability).

## Files

| File | Layer | Action |
|---|---|---|
| `Application/DTOs/Vitality/VitalityStatusDto.cs` | Application | Create |
| `Application/DTOs/Vitality/VitalityClaimResultDto.cs` | Application | Create |
| `Application/Interfaces/IVitalityService.cs` | Application | Create |
| `Application/Services/VitalityService.cs` | Application | Create |
| `Application/Helpers/Constant.cs` | Application | Modify — add vitality success/error messages |
| `API/Controllers/VitalityController.cs` | API | Create |
| `API/Program.cs` (or DI extension) | API | Modify — register IVitalityService |
