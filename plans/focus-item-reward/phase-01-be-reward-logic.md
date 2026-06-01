# Phase 1: BE Reward Logic

**Layer:** Application (BE — .NET 8)
**Stories:** P1 (tiered item reward), P2 (isolated `RewardCalculationService`)

## Requirements
Create a pure, stateless `RewardCalculationService` that maps session duration in minutes to a list of reward items using the four hardcoded tiers. No DB access, no latency impact.

## Files

| File | Action | Purpose |
|------|--------|---------|
| `Application/DTOs/FocusSession/RewardItemDto.cs` | Create | Carries `ItemId`, `ItemName`, `Quantity` for one reward line |
| `Application/Services/RewardCalculationService.cs` | Create | Pure service: `Calculate(int minutes) → List<RewardItemDto>` |
| `Application/Interfaces/IRewardCalculationService.cs` | Create | Interface for DI registration |

## Steps
1. Confirm Pesticide UUID by querying the `Items` table in the running DB, or decide to omit the ≥100 min Pesticide tier for demo. Record the UUID (or the omission decision) before writing any code.
2. Create `RewardItemDto` with three properties: `ItemId` (Guid), `ItemName` (string), `Quantity` (int). Place it in the `Application/DTOs/FocusSession/` folder alongside the existing DTO.
3. Create `IRewardCalculationService` with a single method signature `Calculate(int durationMinutes)` returning `List<RewardItemDto>`.
4. Implement `RewardCalculationService` — hardcode the five-tier switch (no-reward, 25–49, 50–74, 75–99, ≥100) using the known item UUIDs and names. Method must be pure: no injected dependencies, no DB calls.
5. Write a quick manual verification: instantiate `RewardCalculationService` in a scratch test or breakpoint and assert the five boundary values (24, 25, 50, 75, 100 min) return the correct counts before moving to Phase 2.

## Success Criteria
- `RewardCalculationService.Calculate(24)` returns an empty list
- `RewardCalculationService.Calculate(25)` returns exactly `[{WateringCan, qty=2}]`
- `RewardCalculationService.Calculate(50)` returns `[{WateringCan, qty=2}, {Fertilizer, qty=1}]`
- `RewardCalculationService.Calculate(75)` returns `[{WateringCan, qty=3}, {Fertilizer, qty=2}]`
- `RewardCalculationService.Calculate(100)` returns 3 items (or 2 if Pesticide UUID is omitted for demo)
- No DB query is issued during any `Calculate()` call (verify via SQL profiler or log)

## Risks
- Pesticide UUID unknown: query `SELECT Id, Name FROM Items WHERE Name LIKE '%Pesticide%'` before coding; if absent, omit that tier and document it as a known gap
