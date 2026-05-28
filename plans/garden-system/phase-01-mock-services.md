# Phase 01 — Mock Services

## Layer
`services/` — imports `domain/` only. No Node, no autoload references.

## Files

| File | Path | Action | Layer |
|------|------|--------|-------|
| MockGardenService.gd | res://services/MockGardenService.gd | NEW | services |
| MockInventoryService.gd | res://services/MockInventoryService.gd | NEW | services |

## User Stories Covered
- Enables US-03 (plant seed), US-05 (stage visual), US-06 (harvest) — provides mock data

## Implementation Steps

### 1. MockGardenService.gd

```gdscript
class_name MockGardenService
extends RefCounted

func get_flower_templates() -> Array[FlowerTemplate]:
    var sunflower := FlowerTemplate.new()
    sunflower.id = "sunflower"
    sunflower.name = "Sunflower"                             # FlowerTemplate.name (not display_name)
    sunflower.harvest_product_id = "harvest_sunflower_bloom"
    sunflower.stages = _make_stages([
        {level=1, xp=0,   model_key="sunflower_sprout"},
        {level=4, xp=100, model_key="sunflower_bud"},
        {level=7, xp=300, model_key="sunflower_bloom"},
    ])

    var rose := FlowerTemplate.new()
    rose.id = "rose"
    rose.name = "Rose"
    rose.harvest_product_id = "harvest_rose_bloom"
    rose.stages = _make_stages([
        {level=1, xp=0,   model_key="rose_sprout"},
        {level=4, xp=120, model_key="rose_bud"},
        {level=7, xp=360, model_key="rose_bloom"},
    ])

    return [sunflower, rose]

func get_initial_plots(garden_id: String) -> Array[Plot]:
    var plots: Array[Plot] = []
    for i in range(8):
        # Plot._init(p_id, p_garden_id, p_index) — use constructor args
        var p := Plot.new("plot_%d" % i, garden_id, i)
        plots.append(p)
    return plots

func _make_stages(data: Array) -> Array[StageDefinition]:
    var result: Array[StageDefinition] = []
    for d in data:
        var s := StageDefinition.new()
        s.level = d.level
        s.xp_required = d.xp
        s.model_key = d.model_key
        result.append(s)
    return result
```

### 2. MockInventoryService.gd

```gdscript
class_name MockInventoryService
extends RefCounted

func get_initial_inventory() -> UserInventory:
    var inv := UserInventory.new()
    inv.items = []

    for i in range(3):
        var seed := InventoryItem.new()
        seed.id = "seed_sunflower_%d" % i
        seed.flower_template_id = "sunflower"   # SEED: reference_id = flower_template_id
        seed.category = InventoryItem.Category.SEED
        seed.quantity = 1
        inv.items.append(seed)

    for i in range(3):
        var seed := InventoryItem.new()
        seed.id = "seed_rose_%d" % i
        seed.flower_template_id = "rose"         # SEED: reference_id = flower_template_id
        seed.category = InventoryItem.Category.SEED
        seed.quantity = 1
        inv.items.append(seed)

    return inv
```

## Acceptance Test

- Call `MockGardenService.new().get_flower_templates()` → array length == 2, sunflower.stages.size() == 3
- Call `MockInventoryService.new().get_initial_inventory()` → items with reference_id "sunflower_seed" count == 3
- No Node imports, no autoload references, no print() calls
