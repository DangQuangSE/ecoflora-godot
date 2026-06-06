# Phase 1: BE Foundation

**Codebase:** eco-backend (`d:\WorkWithCorn\eco-backend\`)

## Requirements
Persist XP on the server so that player progression survives sessions. Every write operation that awards plant XP must also increment the user's account-level XP and return the new totals to the caller. The harvest currency bug is removed at the same time.

## Steps
1. Add `CurrentXP int` (default 0) and `VitalityReadyAt DateTime?` (nullable, default null) to `User.cs` in `Domain/Entities/`. Mark `VitalityReadyAt` with `[ConcurrencyCheck]` (EF Core attribute) so concurrent writes to that column throw `DbUpdateConcurrencyException` — this is the DB-level guard against double-claim. Run `dotnet ef migrations add AddUserXpAndVitality` and apply it to the dev database.
2. Fix `MappingProfile.cs`: replace the hardcoded `.MapFrom(src => 0)` for `CurrentXp` with `.MapFrom(src => src.CurrentXP)`. Add `VitalityReadyAt` to `UserDto` as `DateTime? VitalityReadyAt` so the profile endpoint exposes it.
3. Define level-threshold constants in `Application/Helpers/Constant.cs` (or a new `LevelConstants` static class): L2=500, L3=1500, L4=3000, L5=5000, L6=8000, L7=12000. Add a static helper method `ComputeLevel(int totalXp) -> int` that iterates these thresholds.
4. Update `GardenService.HarvestFlowerAsync()`: delete `user.Currency += template.BasePrice`, add `user.CurrentXP += xpEarned`, call `ComputeLevel` to determine the new level, set `user.Level = newLevel`, and persist the user update inside the existing transaction. Add `NewUserXP int` and `NewUserLevel int` fields to `HarvestRewardDto`. **Note:** The Godot-side handler `GardenManager.gd` (`_on_harvest_completed`) must also be updated in Phase 4 Step 6 to call `apply_server_xp(newUserXP, newUserLevel)` and retire the old `add_harvest_xp(xp_earned)` call — the two phases must ship together or the client will read stale `xpEarned` as user XP.
5. Update `GardenService.CareForFlowerAsync()`: add `user.CurrentXP += careItem.Item.ReceivedExp`, call `ComputeLevel`, set `user.Level`, persist user inside the existing transaction. Add `NewUserXP int` and `NewUserLevel int` fields to `CareResponseDto`.
6. Verify `UserService.cs` (Application layer) already maps `Level` from `User` correctly and that the profile endpoint (`GET /api/auth/profile`) now returns non-zero `currentXp` after a harvest or care action. Confirm with a manual Swagger test: earn XP, re-fetch profile, assert `currentXp > 0`.
7. Add `VitalityReadyAt` to `AppDbContext.OnModelCreating` only if any explicit column config is needed (nullable DateTime? typically needs no extra fluent config in EF Core 8). Confirm the migration SQL in the generated `.cs` file before applying.

## Success Criteria
- `dotnet ef migrations add` produces a valid migration file with `AlterTable("Users")` adding `CurrentXP` (int, not null, default 0) and `VitalityReadyAt` (datetime, nullable).
- After applying migration: existing rows have `CurrentXP = 0`, `VitalityReadyAt = NULL`.
- `GET /api/auth/profile` returns `"currentXp": <non-zero>` after the player earns XP via harvest or care in the same session.
- `POST /api/garden/{gardenId}/plots/{plotId}/harvest` response body contains `newUserXP` and `newUserLevel` fields with correct values.
- `POST /api/garden/{gardenId}/plots/{plotId}/care` response body contains `newUserXP` and `newUserLevel`.
- Harvesting a flower no longer changes `user.Currency` (confirmed by checking currency before and after harvest via profile endpoint).

## Risks
- Removing currency-on-harvest breaks current player economy expectations: coordinate with team and run behind a feature flag or deploy during a scheduled maintenance window.
- `ComputeLevel` must be idempotent and match the thresholds used in Godot's `UserProfile.add_xp()` — mismatched tables will cause level display to differ between client and server.

## Files

| File | Layer | Action |
|---|---|---|
| `Domain/Entities/User.cs` | Domain | Modify — add `CurrentXP int`, `VitalityReadyAt DateTime?` |
| `Application/DTOs/User/UserDto.cs` | Application | Modify — add `VitalityReadyAt DateTime?` |
| `Application/Mapper/MappingProfile.cs` | Application | Modify — fix `CurrentXp` mapping, add `VitalityReadyAt` mapping |
| `Application/Helpers/Constant.cs` | Application | Modify — add level threshold constants |
| `Application/Helpers/LevelHelper.cs` | Application | Create — static `ComputeLevel(int xp) -> int` helper |
| `Application/DTOs/Garden/HarvestRewardDto.cs` | Application | Modify — add `NewUserXP int`, `NewUserLevel int` |
| `Application/DTOs/Garden/CareResponseDto.cs` | Application | Modify — add `NewUserXP int`, `NewUserLevel int` |
| `Application/Services/GardenService.cs` | Application | Modify — harvest removes currency earn, both harvest+care add User.CurrentXP and return new XP/level |
| `Infrastructure/Migrations/<timestamp>_AddUserXpAndVitality.cs` | Infrastructure | Create — EF Core migration |
