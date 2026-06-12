# Phase 3: Autoloads — GardenManager Synergy Integration

## Layer
`autoloads/` — GardenManager

## Files

| File | Layer | Action |
|------|-------|--------|
| `autoloads/GardenManager.gd` | autoloads | Modify |

## Stories
P1-1, P1-3, P2-2

## Requirements

Integrate `SynergyEvaluator` into all care paths with optimistic UI pattern.

### Helper method (private)

```gdscript
func _build_plots_by_index() -> Dictionary:
    var map: Dictionary = {}
    for p: Plot in _plots:
        map[p.plot_index] = p
    return map

func _get_synergy_bonus(plot_id: String) -> int:
    var plot := _find_plot(plot_id)
    if plot == null:
        return 0
    return SynergyEvaluator.get_bonus_for_plot(
        plot.plot_index,
        _build_plots_by_index(),
        _templates,
        _synergy_cache
    )
```

### Mock paths (`water`, `fertilize`, `pesticide`)

Replace fixed XP with:

```gdscript
var base_xp := WATER_XP  # or FERTILIZE_XP
var bonus := _get_synergy_bonus(plot_id)
var total := base_xp + bonus
plot.current_plant.current_xp += total
plant_xp_gained.emit(plot_id, total)
```

### BE path (`_care_action`)

**Before optimistic mutation:**

```gdscript
var bonus := _get_synergy_bonus(plot_id)
var xp_delta := base_from_item + bonus
```

**After 200 response:**

- Prefer authoritative `updatedPlot.plantedFlower.currentXp` (already done)
- Parse `synergyBonusXp` from response — if optimistic total differed, plot XP already overwritten
- Optionally emit extended signal if bonus > 0 (Phase 4)

### Signal extension (optional for Phase 4)

Consider changing to:

```gdscript
signal plant_xp_gained(plot_id: String, xp_amount: int, synergy_bonus: int)
```

Default `synergy_bonus = 0` for backward compat — or add separate `synergy_bonus_applied(zone_id, amount)`.

## Steps

1. Add `_build_plots_by_index()` and `_get_synergy_bonus()`.
2. Update mock `water`, `fertilize`, `pesticide` to add bonus.
3. Update `_care_action` optimistic xp_delta.
4. Parse `synergyBonusXp` / `totalXpGranted` from care response envelope.
5. Ensure plant/harvest do **not** need changes — bonus is lazy at care time (P2-2 satisfied).

## Tests to Write First

- Mock: zone_0 plots 0–1 both sun_flower (Sun Chaser) → water plot_0 → +30 XP (20+10)
- Mock: only 1 sun_flower in zone_0 → water → +20 only (below min 2)
- Mock: plot_0 sunflower + plot_1 rose (null synergy) → water → +20 only
- BE mock-off: optimistic then reconcile (manual)

## Verification

```bash
godot --headless --check-only --script res://autoloads/GardenManager.gd
```

Play in editor mock mode with 3 same-synergy flowers in zone_0.

## Acceptance

- [ ] `is_pending_sync` guard unchanged
- [ ] Rollback restores pre-care XP including any optimistic bonus
- [ ] BE 200 overwrites with server XP
- [ ] No `print()` — use `push_warning` on parse errors only
