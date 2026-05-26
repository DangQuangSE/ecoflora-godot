# Phase 02 — Autoloads

## Layer
`autoloads/` — imports `domain/` + `services/`. No scenes imports. Communicates with scenes via signals only.

## Files

| File | Path | Action | Layer |
|------|------|--------|-------|
| GardenManager.gd | res://autoloads/GardenManager.gd | NEW | autoloads |
| InventoryManager.gd | res://autoloads/InventoryManager.gd | NEW | autoloads |
| InteractionManager.gd | res://autoloads/InteractionManager.gd | NEW (stub) | autoloads |

## User Stories Covered
- US-01 (8 plots), US-03 (plant), US-06 (harvest), US-07 (inventory update)

## Implementation Steps

### 1. GardenManager.gd

```gdscript
extends Node

signal plots_updated(plots: Array[Plot])
signal plant_failed(plot_id: String, reason: String)
signal harvest_completed(plot_id: String, product_id: String)

const GARDEN_ID := "main_garden"

var _plots: Array[Plot] = []
var _templates: Dictionary = {}  # id -> FlowerTemplate

# Hardcoded world positions for 8 plots (2×4 grid), adjust to match TileMap
const PLOT_POSITIONS: Array[Vector2] = [
    Vector2(80, 80),   Vector2(180, 80),
    Vector2(80, 180),  Vector2(180, 180),
    Vector2(80, 280),  Vector2(180, 280),
    Vector2(80, 380),  Vector2(180, 380),
]

func _ready() -> void:
    var garden_svc := MockGardenService.new()
    _plots = garden_svc.get_initial_plots(GARDEN_ID)
    for t in garden_svc.get_flower_templates():
        _templates[t.id] = t

func get_plots() -> Array[Plot]:
    return _plots

func get_plot_position(index: int) -> Vector2:
    return PLOT_POSITIONS[index] if index < PLOT_POSITIONS.size() else Vector2.ZERO

func get_templates() -> Dictionary:
    return _templates

func plant(plot_id: String, flower_template_id: String) -> void:
    var plot := _find_plot(plot_id)
    if plot == null or plot.is_occupied or plot.is_pending_sync:
        plant_failed.emit(plot_id, "not_available")
        return
    var template: FlowerTemplate = _templates.get(flower_template_id)
    if template == null:
        plant_failed.emit(plot_id, "unknown_template")
        return

    plot.is_pending_sync = true
    # Optimistic update — PlantedFlower._init(template_id, uid) sets id + planted_at automatically
    var flower := PlantedFlower.new(flower_template_id, "")
    flower.current_xp = 0
    flower.current_stage = template.compute_stage_for_xp(0)
    plot.plant(flower)
    plots_updated.emit(_plots)

    # Mock async sync (immediate)
    await Engine.get_main_loop().process_frame
    plot.is_pending_sync = false
    plots_updated.emit(_plots)

func add_xp(plot_id: String, xp_amount: int) -> void:
    var plot := _find_plot(plot_id)
    if plot == null or not plot.is_occupied or plot.is_pending_sync:
        return
    var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
    if template == null:
        return

    plot.is_pending_sync = true
    plot.current_plant.current_xp += xp_amount
    plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
    plots_updated.emit(_plots)
    await Engine.get_main_loop().process_frame
    plot.is_pending_sync = false
    plots_updated.emit(_plots)

func harvest(plot_id: String) -> void:
    var plot := _find_plot(plot_id)
    if plot == null or not plot.is_occupied or plot.is_pending_sync:
        return
    var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
    if template == null:
        return
    if plot.current_plant.current_stage < template.get_max_stage_level():
        return

    plot.is_pending_sync = true
    var product_id := template.harvest_product_id
    plot.clear()
    plots_updated.emit(_plots)
    harvest_completed.emit(plot_id, product_id)
    await Engine.get_main_loop().process_frame
    plot.is_pending_sync = false
    plots_updated.emit(_plots)

func _find_plot(plot_id: String) -> Plot:
    for p in _plots:
        if p.id == plot_id:
            return p
    return null
```

### 2. InventoryManager.gd

```gdscript
extends Node

signal inventory_updated(inventory: UserInventory)

var _inventory: UserInventory

func _ready() -> void:
    _inventory = MockInventoryService.new().get_initial_inventory()

func get_inventory() -> UserInventory:
    return _inventory

func has_seed(flower_template_id: String) -> bool:
    # SEED.get_reference_id() returns flower_template_id — search by that directly
    return _inventory.find_by_reference_id(flower_template_id) != null

func consume_seed(flower_template_id: String) -> bool:
    var item := _inventory.find_by_reference_id(flower_template_id)
    if item == null:
        return false
    _inventory.items.erase(item)
    inventory_updated.emit(_inventory)
    return true

func add_harvest_product(product_id: String) -> void:
    var existing := _inventory.find_harvest_product(product_id)
    if existing != null:
        existing.quantity += 1
    else:
        var item := InventoryItem.new()
        item.id = "harvest_%s_%d" % [product_id, _inventory.items.size()]
        item.harvest_product_id = product_id   # HARVEST_PRODUCT field (not reference_id)
        item.category = InventoryItem.Category.HARVEST_PRODUCT
        item.quantity = 1
        _inventory.items.append(item)
    inventory_updated.emit(_inventory)
```

### 3. InteractionManager.gd (stub)

```gdscript
extends Node

signal plot_action_requested(plot_id: String, action: String, data: Dictionary)

func request_plot_action(plot_id: String, action: String, data: Dictionary = {}) -> void:
    plot_action_requested.emit(plot_id, action, data)
```

### 4. Wire GardenManager ↔ InventoryManager via signals (in GardenManager._ready)

```gdscript
# In GardenManager._ready():
harvest_completed.connect(func(plot_id: String, product_id: String):
    InventoryManager.add_harvest_product(product_id)
)
```

### 5. Wire InteractionManager → GardenManager (in GardenManager._ready)

```gdscript
# In GardenManager._ready():
InteractionManager.plot_action_requested.connect(_on_plot_action)

func _on_plot_action(plot_id: String, action: String, data: Dictionary) -> void:
    match action:
        "plant":   plant(plot_id, data.get("template_id", ""))
        "harvest": harvest(plot_id)
        "add_xp":  add_xp(plot_id, data.get("amount", 150))
```

## Acceptance Test

- GardenManager._ready() runs without errors — `get_plots()` returns array of 8 empty Plot objects
- `InventoryManager.has_seed("sunflower")` → true (initial inventory has sunflower_seed)
- `GardenManager.plant("plot_0", "sunflower")` → `plots_updated` emits, plot_0.is_occupied == true
- `GardenManager.harvest("plot_0")` on a non-max-stage plot → no harvest (stage check fails)
- No push_error, no print() in console
