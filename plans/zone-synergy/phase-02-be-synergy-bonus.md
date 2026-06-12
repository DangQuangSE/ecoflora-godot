# Phase 2: BE — Authoritative Synergy Bonus on Care

## Layer
`eco-backend`: Application + Domain helpers

## Files

| File | Layer | Action |
|------|-------|--------|
| `Application/Helpers/ZonePlotHelper.cs` | Application | New |
| `Application/Helpers/SynergyEvaluator.cs` | Application | New |
| `Application/DTOs/Garden/CareResponseDto.cs` | Application | Modify |
| `Application/Services/GardenService.cs` | Application | Modify |

## Stories
P1-2

## Requirements

Server **must** compute synergy bonus — client cannot trust local cache alone.

### ZonePlotHelper

Mirror Godot `ZonePlotMap` — same 7×8 zone boundaries from existing `ZoneDefinitions`.

```csharp
public static class ZonePlotHelper
{
    public static string GetZoneIdForPlotIndex(int plotIndex);
    public static IEnumerable<Plot> GetPlotsInZone(IReadOnlyList<Plot> orderedPlots, string zoneId);
}
```

Use `Plot.PlotIndex` ordering (garden plots already ordered by index in repository).

### SynergyEvaluator (C#)

```csharp
public static class SynergyEvaluator
{
    public static (bool Active, Guid? SynergyId, int XpPlus) EvaluateZone(
        IEnumerable<Plot> zonePlots,
        Func<Guid, FlowerTemplate?> getTemplate);

    // Load Synergy entity for XpPlus when active
}
```

Rules identical to Godot spec: empty plots ignored, **≥ 2 occupied**, non-null synergy, all same.

### GardenService.CareForFlowerAsync changes

After loading target plot:

1. Load all garden plots with flowers (may need `GetGardenWithPlotsAndFlowersAsync` or reuse existing query).
2. Determine zone of `plot.PlotIndex`.
3. Evaluate synergy for plots in that zone.
4. `var totalXp = careItem.Item.ReceivedExp + synergyXpPlus;`
5. `flower.CurrentXp += totalXp;`

### CareResponseDto

Add:

```csharp
public int SynergyBonusXp { get; set; }  // 0 if inactive
public int TotalXpGranted { get; set; }    // base + bonus — optional but helps client UI
```

JSON: `synergyBonusXp`, `totalXpGranted` (camelCase via serializer).

## Steps

1. Add `ZonePlotHelper.cs` extracting logic from `BuildZoneStates` offset math.
2. Add `SynergyEvaluator.cs` in Application/Helpers.
3. Extend `CareResponseDto`.
4. In `CareForFlowerAsync`:
   - **Before transaction:** `GetByUserIdWithDetailsAsync(userGuid)` (AsNoTracking) to load all plots + flowers + templates for zone eval
   - Filter plots in target zone via `ZonePlotHelper`
   - Compute bonus via `SynergyEvaluator`
   - Inside transaction: apply `ReceivedExp + synergyXpPlus` to XP
   - Populate response fields
5. `FlowerTemplate.SynergyId` already included via existing `ThenInclude` on repository — no migration needed.

## Tests to Write First

- Unit test: 8 plots zone, 3 with same SynergyId → XpPlus returned
- Unit test: mixed SynergyId → 0
- Integration: POST care → response `synergyBonusXp > 0` when zone pure

## Verification

```bash
dotnet build eco-backend.sln
# Swagger: care on plot in pure Sun Chaser zone → synergyBonusXp = 10
```

## Acceptance

- [ ] Bonus computed server-side only
- [ ] Rules match Godot domain evaluator
- [ ] CareResponseDto exposes bonus for client reconcile
- [ ] No client-sent bonus field in CareRequest (anti-cheat)

## Notes

- Repository may need `GetPlotByIdWithFlowerAsync` to Include `FlowerTemplate` — verify existing includes.
- If query too heavy, load only plots in same zone (8 max) by plot index range.
