# Phase 2: BE Response Contract

**Layer:** Application + API (BE — .NET 8)
**Stories:** P1 (reward returned in PATCH response), P2 (controller only calls `CalculateReward`)

## Requirements
Extend `PATCH /api/focus-sessions/{id}/complete` so the response body includes `rewardItems` and the items are actually granted to the user's inventory before the response is returned.

## Files

| File | Action | Purpose |
|------|--------|---------|
| `Application/DTOs/FocusSession/FocusSessionDto.cs` | Edit | Add `List<RewardItemDto> RewardItems { get; set; }` |
| `Application/Services/FocusSessionService.cs` | Edit | Inject `IRewardCalculationService`; call `Calculate()` + `GrantItemAsync()` in `CompleteAsync()` only |
| `API/Program.cs` | Edit | Register `IRewardCalculationService → RewardCalculationService` in DI |

## Steps
1. Add `List<RewardItemDto> RewardItems { get; set; } = new();` to `FocusSessionDto`. This field is intentionally skipped by AutoMapper (no entity property) — confirm the AutoMapper profile does not throw on unmapped destination member, or add an explicit `.Ignore()` if needed.
2. Inject `IRewardCalculationService` into `FocusSessionService` via constructor (alongside existing `IUnitOfWork` and `IMapper`).
3. In `CompleteAsync()`, after the existing `UpdateStatusAsync()` call succeeds and the base DTO is mapped, call `Calculate(session.TargetDuration)` to get the reward list. **Decision (intentional):** use `TargetDuration`, not elapsed time. In Pomodoro, the timer fires at zero — the user focused for exactly the duration they set. Using `TargetDuration` is correct and avoids storing `EndTime`. Document this in a code comment.
4. For each item in the reward list, call `InventoryService.GrantItemAsync()` with the user's GUID, the item's `ItemId`, and `Quantity`. Collect any errors with `push_warning` equivalent (log and continue) — do not abort the complete response if a grant fails.
5. Populate `dto.RewardItems` from the calculated list (use the data from step 3, not the grant results) and return the DTO.
6. Register `IRewardCalculationService` as a scoped (or singleton) service in `Program.cs`. Verify the app starts without DI errors.

## Success Criteria
- `POST /api/focus-sessions` then `PATCH /api/focus-sessions/{id}/complete` returns HTTP 200 with JSON containing `rewardItems` array
- For a 25-min session: `rewardItems` has one entry, `quantity = 2`, itemName contains "Watering" (case-insensitive)
- DB `InventoryItems` table shows the granted items incremented after the PATCH call
- `PATCH /api/focus-sessions/{id}/fail` response does NOT include `rewardItems` (fails path uses `UpdateStatusAsync` unchanged)
- App still starts cleanly (`dotnet run` no exceptions on boot)

## Risks
- AutoMapper may throw `UnmappedMemberException` for `RewardItems` on `FocusSessionDto` — add `.ForMember(d => d.RewardItems, opt => opt.Ignore())` in the mapping profile if needed
- `GrantItemAsync` commits per-item; a mid-loop DB failure leaves partial rewards persisted — acceptable for demo, log at warning level
- **Non-idempotent endpoint**: `PATCH .../complete` grants items on every call. Godot client MUST NOT retry on timeout — treat any non-200 response as a silent failure (log warning, keep UI result). Add a comment to the controller method marking it `[NonIdempotent]`.
