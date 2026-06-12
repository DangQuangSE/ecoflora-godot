# Phase 1: Domain — Zone Plot Map & Synergy Evaluator

## Layer
`domain/` — RefCounted only

## Files

| File | Layer | Action |
|------|-------|--------|
| `domain/ZonePlotMap.gd` | domain | New |
| `domain/SynergyEvaluator.gd` | domain | New |

## Stories
P1-1

## Requirements

Pure functions — no Node, no autoload imports, no `get_tree()`.

### ZonePlotMap

Static mapping khớp BE `GardenService.ZoneDefinitions`:

| Zone | Plot indices |
|------|--------------|
| zone_0 | 0–7 |
| zone_1 | 8–15 |
| zone_2 | 16–23 |
| zone_3 | 24–31 |
| zone_4 | 32–39 |
| zone_5 | 40–47 |
| zone_6 | 48–55 |

API:

```gdscript
class_name ZonePlotMap
extends RefCounted

static func get_zone_id_for_plot_index(plot_index: int) -> String
static func get_plot_indices_for_zone(zone_id: String) -> Array[int]
```

### SynergyEvaluator

```gdscript
class_name SynergyEvaluator
extends RefCounted

# Returns { "active": bool, "synergy_id": String, "xp_plus": int }
static func evaluate_zone(
    zone_plot_indices: Array[int],
    plots_by_index: Dictionary,  # int -> Plot
    templates: Dictionary       # flower_template_id -> FlowerTemplate
) -> Dictionary

static func get_bonus_for_plot(
    plot_index: int,
    plots_by_index: Dictionary,
    templates: Dictionary,
    synergy_cache: Dictionary   # synergy_id -> { xp_plus, ... }
) -> int
```

**Evaluation rules (must match spec):**

1. Collect occupied plots in zone whose index is in `zone_plot_indices`.
2. If **fewer than 2** occupied → `active = false`, bonus = 0.
3. For each occupied plot, resolve `template.synergy_id`.
4. If any synergy_id is empty → not active.
5. If not all synergy_ids identical → not active.
6. Else lookup `synergy_cache[synergy_id].xp_plus` (0 if missing).

Helper to build `plots_by_index` from `Array[Plot]`: index by `plot.plot_index`.

## Steps

1. Create `ZonePlotMap.gd` with constants + two static methods.
2. Create `SynergyEvaluator.gd` with `evaluate_zone` and `get_bonus_for_plot`.
3. `get_bonus_for_plot` calls `ZonePlotMap.get_zone_id_for_plot_index`, gets indices, evaluates, returns xp_plus.

## Tests to Write First

- Zone with 3 occupied, all synergy A → bonus = A.xp_plus
- Zone with 0 or 1 occupied → bonus 0
- Zone with 1 rose (null synergy) → bonus 0
- Zone with 2 Sun Chaser + 1 Water Lover → bonus 0
- Zone with exactly 2 same synergy → bonus active
- plot_index 16 → zone_2

## Verification

```bash
godot --headless --check-only --script res://domain/SynergyEvaluator.gd
```

Manual: add temporary assertions in `tools/run_tests.gd` if test harness exists.

## Acceptance

- [ ] No Node/autoload imports in domain files
- [ ] Evaluator returns 0 for all edge cases in spec
- [ ] Zone map covers indices 0–55
