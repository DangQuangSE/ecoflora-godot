# Phase 4: Scenes — Synergy Feedback (Float Label + Zone Indicator)

## Layer
`scenes/`

## Files

| File | Layer | Action |
|------|-------|--------|
| `scenes/garden/Plot.gd` | scenes | Modify |
| `autoloads/GardenManager.gd` | autoloads | Modify (signal params) |
| `scenes/garden/SynergyZoneIndicator.gd` | scenes | **New (required)** |
| `scenes/garden/SynergyZoneIndicator.tscn` | scenes | **New (required)** |
| `scenes/garden/GardenScene.gd` | scenes | Modify — spawn + refresh indicators |

## Stories
P2-1, P2-2

## Requirements

Player sees zone-level synergy state persistently (not only on care).

### A. Care float label

Extend `plant_xp_gained` signal:

```gdscript
signal plant_xp_gained(plot_id: String, xp_amount: int, synergy_bonus: int)
```

`Plot._on_plant_xp_gained`:

- `synergy_bonus > 0` → two-line green float: `+%d XP\n+%d 🌿`
- else → existing yellow `+%d XP`

### B. SynergyZoneIndicator (required)

Visual feedback when zone evaluates **active** (≥ 2 same-synergy plants).

**Scene tree:**

```
SynergyZoneIndicator (Node2D)
├── Sprite2D or TextureRect   ← synergy icon (leaf/sparkle placeholder)
└── CPUParticles2D            ← subtle green sparkle loop while active
```

**Script API:**

```gdscript
func setup(zone_id: String, world_position: Vector2) -> void
func set_active(active: bool, synergy_name: String = "") -> void
```

- `active = true` → show icon + emit particles
- `active = false` → hide + stop particles

**Placement:** Center of zone — reuse `ZoneDefinition.world_position` from `ZoneManager` for zones 2–6; compute center for zone_0/zone_1 from plot anchor nodes (same pattern as `GardenScene._zone_overlay_pos`).

### C. GardenScene refresh

```gdscript
func _refresh_synergy_indicators() -> void:
    for zone_id in all_zone_ids:
        var indices := ZonePlotMap.get_plot_indices_for_zone(zone_id)
        var result := SynergyEvaluator.evaluate_zone(indices, plots_by_index, templates)
        _indicators[zone_id].set_active(result.active, synergy_name)
```

Connect:

- `GardenManager.plots_updated` → `_refresh_synergy_indicators()`
- Initial call in `_ready()` after plots spawned

Domain imports (`ZonePlotMap`, `SynergyEvaluator`) allowed in scene script — no autoload→view direct calls.

## Steps

1. Update `plant_xp_gained` signal + all emit sites in `GardenManager`.
2. Update `Plot._on_plant_xp_gained` for dual-line label.
3. Create `SynergyZoneIndicator.tscn` + script (icon + CPUParticles2D).
4. `GardenScene`: spawn one indicator per zone (7 total); store in `_synergy_indicators: Dictionary`.
5. Implement `_refresh_synergy_indicators()` on `plots_updated` and after garden load.
6. Add zone_0/zone_1 world positions (average of plot anchor positions or static offsets in GardenScene).

## Tests to Write First

- 1 cây same synergy → indicator **hidden**
- 2 cây same synergy → indicator **visible**
- Plant 3rd different synergy → indicator **hides immediately** on `plots_updated`
- Water with bonus → green two-line float

## Verification

Run GardenScene: plant 2 sunflowers in zone_0 → indicator appears; harvest one → disappears.

## Acceptance

- [ ] Zone indicator visible only when ≥ 2 same-synergy occupied
- [ ] Indicator updates on plant/harvest without scene reload
- [ ] Float label shows bonus breakdown on care
- [ ] Signal-only UI updates (no Manager→View method calls)

## Godot Editor (post-cook)

See `docs/zone-synergy/godot_implement.md` after `/ck:cook`.
