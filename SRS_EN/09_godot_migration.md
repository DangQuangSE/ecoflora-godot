# 09 — Godot Migration Guide

## Overview

This document helps a developer re-implement Flow & Flora in Godot 4 / GDScript from scratch, using the specs in the other SRS files as the source of truth.

---

## Recommended Tech Stack (Godot)

| Component | Unity | Godot Equivalent |
|-----------|-------|-----------------|
| Engine | Unity 6 | Godot 4.x |
| Language | C# | GDScript 2.0 |
| 2D rendering | URP 2D | Godot 2D (built-in renderer) |
| Async | C# async/await | `await` + Godot signals |
| ScriptableObject | ScriptableObject | `Resource` (.tres file) |
| Singleton | MonoBehaviour + Instance | Autoload singleton |
| Events | C# `event Action` | Godot `signal` |
| Prefab | Unity Prefab | Godot Scene (.tscn) |

---

## Project Structure (Godot)

```
flow_flora_godot/
├── autoloads/                  ← Singleton Managers (registered in Project Settings)
│   ├── GardenManager.gd
│   ├── InventoryManager.gd
│   └── InteractionManager.gd
├── domain/                     ← Pure data classes (RefCounted, no Node)
│   ├── Plot.gd
│   ├── PlantedFlower.gd
│   ├── FlowerTemplate.gd
│   ├── StageDefinition.gd
│   ├── CareAction.gd
│   ├── InventoryItem.gd
│   └── UserInventory.gd
├── services/                   ← Infrastructure (mock + real API)
│   ├── MockGardenService.gd
│   └── MockInventoryService.gd
├── scenes/
│   ├── garden/
│   │   ├── PlotView.tscn + PlotView.gd
│   │   ├── PlantView.tscn + PlantView.gd
│   │   └── ExpBarView.tscn + ExpBarView.gd
│   ├── inventory/
│   │   └── InventoryView.tscn + InventoryView.gd
│   └── hud/
│       └── HarvestButton.tscn + HarvestButton.gd
├── resources/                  ← ItemData resources (.tres files)
│   ├── item_water.tres
│   ├── item_fertilizer.tres
│   ├── flower_sunflower.tres
│   └── ...
└── assets/
```

---

## Domain Classes (GDScript)

### Plot.gd
```gdscript
class_name Plot
extends RefCounted

var id: String
var garden_id: String
var plot_index: int
var is_occupied: bool = false
var is_pending_sync: bool = false
var current_plant: PlantedFlower = null

func plant(flower: PlantedFlower) -> void:
    is_occupied = true
    current_plant = flower

func clear() -> void:
    is_occupied = false
    current_plant = null

func deep_copy() -> Plot:
    var copy := Plot.new()
    copy.id = id
    copy.garden_id = garden_id
    copy.plot_index = plot_index
    copy.is_occupied = is_occupied
    copy.is_pending_sync = is_pending_sync
    copy.current_plant = current_plant.deep_copy() if current_plant else null
    return copy
```

### PlantedFlower.gd
```gdscript
class_name PlantedFlower
extends RefCounted

var id: String
var flower_template_id: String
var user_id: String
var current_xp: int = 0
var current_stage: int = 1
var planted_at: int = 0        # Unix timestamp
var last_watered_at: int = 0
var last_fertilized_at: int = 0

func _init(template_id: String = "", uid: String = "") -> void:
    id = "%d_%d" % [randi(), randi()]  # simple unique ID
    flower_template_id = template_id
    user_id = uid
    current_xp = 0
    current_stage = 1
    planted_at = int(Time.get_unix_time_from_system())

func deep_copy() -> PlantedFlower:
    var copy := PlantedFlower.new(flower_template_id, user_id)
    copy.id = id
    copy.current_xp = current_xp
    copy.current_stage = current_stage
    copy.planted_at = planted_at
    copy.last_watered_at = last_watered_at
    copy.last_fertilized_at = last_fertilized_at
    return copy
```

### FlowerTemplate.gd
```gdscript
class_name FlowerTemplate
extends RefCounted

var id: String
var name: String
var base_price: int
var image_url: String
var synergy_id: String
var harvest_product_id: String
var stages: Array = []  # Array[StageDefinition]

func get_max_stage_level() -> int:
    var max_level := 1
    for s in stages:
        if s.level > max_level:
            max_level = s.level
    return max_level

func compute_stage_for_xp(current_xp: int) -> int:
    if stages.is_empty():
        return 1
    var best_level: int = stages[0].level
    var best_xp: int    = stages[0].xp_required
    for s in stages:
        if s.xp_required <= current_xp and s.xp_required >= best_xp:
            best_level = s.level
            best_xp    = s.xp_required
    return best_level

func get_xp_required_for_stage(level: int) -> int:
    for s in stages:
        if s.level == level:
            return s.xp_required
    return 0

func get_next_stage_xp(current_stage: int) -> int:
    var next_level := 999999
    var next_xp    := -1
    for s in stages:
        if s.level > current_stage and s.level < next_level:
            next_level = s.level
            next_xp    = s.xp_required
    return next_xp
```

### CareAction.gd
```gdscript
class_name CareAction
extends RefCounted

const PLANT     := "PLANT"
const WATER     := "WATER"
const FERTILIZE := "FERTILIZE"
const PESTICIDE := "PESTICIDE"
const HARVEST   := "HARVEST"

var action_id: String
var plot_id: String
var action_type: String
var reference_id: String
var timestamp: int

func _init(pid: String = "", atype: String = "", ref_id: String = "") -> void:
    action_id  = "%d_%d" % [randi(), randi()]
    plot_id    = pid
    action_type = atype
    reference_id = ref_id
    timestamp  = int(Time.get_unix_time_from_system())
```

---

## Autoload Singletons

Register in **Project → Project Settings → Autoload**:

| Name | Path |
|------|------|
| `GardenManager` | `res://autoloads/GardenManager.gd` |
| `InventoryManager` | `res://autoloads/InventoryManager.gd` |
| `InteractionManager` | `res://autoloads/InteractionManager.gd` |

### GardenManager.gd (skeleton)
```gdscript
extends Node

signal garden_state_updated(plots: Array)
signal action_synced(plot_id: String, action_type: String)

var current_plots: Array = []        # Array[Plot]
var flower_templates: Dictionary = {} # String -> FlowerTemplate
var current_user_id: String = "user_default"

func _ready() -> void:
    _initialize_garden()

func _initialize_garden() -> void:
    var mock := MockGardenService.new()
    var templates: Array = await mock.get_flower_templates_async()
    for t in templates:
        flower_templates[t.id] = t
    current_plots = await mock.get_garden_state_async(current_user_id)
    garden_state_updated.emit(current_plots)

func optimistic_plant(plot_id: String, flower_template_id: String) -> void:
    var plot := get_plot(plot_id)
    if not plot or plot.is_occupied or plot.is_pending_sync:
        return
    var seed_entry = InventoryManager.find_entry_by_reference_id(flower_template_id)
    if not seed_entry:
        return
    # Local predict
    plot.is_pending_sync = true
    plot.plant(PlantedFlower.new(flower_template_id, current_user_id))
    InventoryManager.local_remove_item(seed_entry.id, 1)
    garden_state_updated.emit(current_plots)
    # Async sync
    var mock := MockGardenService.new()
    var action := CareAction.new(plot_id, CareAction.PLANT, flower_template_id)
    var result: Array = await mock.sync_batch_actions_async(current_user_id, [action])
    if result != null:
        plot.is_pending_sync = false
        current_plots = result
        garden_state_updated.emit(current_plots)
    else:
        plot.clear()
        plot.is_pending_sync = false
        InventoryManager.local_add_item(seed_entry.id, 1)
        garden_state_updated.emit(current_plots)

func optimistic_harvest(plot_id: String) -> void:
    var plot := get_plot(plot_id)
    if not plot or not plot.is_occupied or plot.is_pending_sync:
        return
    var plant := plot.current_plant
    var template: FlowerTemplate = flower_templates.get(plant.flower_template_id)
    if not template:
        return
    if plant.current_stage < template.get_max_stage_level():
        return
    var harvest_product_id := template.harvest_product_id
    var snapshot := plant.deep_copy()
    # Local predict
    plot.is_pending_sync = true
    plot.clear()
    InventoryManager.local_grant_harvest_item(harvest_product_id, 1)
    garden_state_updated.emit(current_plots)
    # Async sync
    var mock := MockGardenService.new()
    var action := CareAction.new(plot_id, CareAction.HARVEST, harvest_product_id)
    var result: Array = await mock.sync_batch_actions_async(current_user_id, [action])
    if result != null:
        plot.is_pending_sync = false
        current_plots = result
        garden_state_updated.emit(current_plots)
    else:
        plot.plant(snapshot)
        plot.is_pending_sync = false
        InventoryManager.local_revoke_harvest_item(harvest_product_id, 1)
        garden_state_updated.emit(current_plots)

func get_plot(plot_id: String) -> Plot:
    for p in current_plots:
        if p.id == plot_id:
            return p
    return null

func get_flower_template(id: String) -> FlowerTemplate:
    return flower_templates.get(id, null)
```

---

## Mock Service (GDScript)

### MockGardenService.gd
```gdscript
class_name MockGardenService
extends RefCounted

var _plots: Array = []
var _templates: Dictionary = {}
var _consumables: Dictionary = {}  # item_id -> {received_exp: int}

func _init() -> void:
    _seed_templates()
    _seed_consumables()
    _seed_plots()

func _seed_templates() -> void:
    var sunflower := FlowerTemplate.new()
    sunflower.id = "flower_sunflower"
    sunflower.name = "Sunflower"
    sunflower.base_price = 50
    sunflower.harvest_product_id = "harvest_sunflower_bloom"
    var s1 := StageDefinition.new(); s1.level = 1; s1.xp_required = 0;   s1.model_key = "stage_seedling"
    var s2 := StageDefinition.new(); s2.level = 4; s2.xp_required = 100; s2.model_key = "stage_young"
    var s3 := StageDefinition.new(); s3.level = 7; s3.xp_required = 300; s3.model_key = "stage_mature"
    sunflower.stages = [s1, s2, s3]
    _templates["flower_sunflower"] = sunflower

    var rose := FlowerTemplate.new()
    rose.id = "flower_rose"
    rose.name = "Rose"
    rose.base_price = 80
    rose.harvest_product_id = "harvest_rose_bloom"
    var r1 := StageDefinition.new(); r1.level = 1; r1.xp_required = 0;   r1.model_key = "stage_seedling"
    var r2 := StageDefinition.new(); r2.level = 4; r2.xp_required = 120; r2.model_key = "stage_young"
    var r3 := StageDefinition.new(); r3.level = 7; r3.xp_required = 360; r3.model_key = "stage_mature"
    rose.stages = [r1, r2, r3]
    _templates["flower_rose"] = rose

func _seed_consumables() -> void:
    _consumables["item_water"]      = {"received_exp": 20}
    _consumables["item_fertilizer"] = {"received_exp": 50}
    _consumables["item_pesticide"]  = {"received_exp": 50}

func _seed_plots() -> void:
    for i in range(9):
        var p := Plot.new()
        p.id = "plot_%d" % i
        p.garden_id = "garden_default"
        p.plot_index = i
        _plots.append(p)
    var pre_plant := PlantedFlower.new("flower_sunflower", "user_default")
    pre_plant.current_xp = 50
    _plots[0].plant(pre_plant)

func get_garden_state_async(user_id: String) -> Array:
    await Engine.get_main_loop().create_timer(0.05).timeout
    return _plots.map(func(p): return p.deep_copy())

func get_flower_templates_async() -> Array:
    await Engine.get_main_loop().create_timer(0.03).timeout
    return _templates.values()

func sync_batch_actions_async(user_id: String, actions: Array) -> Array:
    await Engine.get_main_loop().create_timer(0.05).timeout
    for action in actions:
        _apply_action(action, user_id)
    return _plots.map(func(p): return p.deep_copy())

func _apply_action(action: CareAction, user_id: String) -> void:
    var plot: Plot = null
    for p in _plots:
        if p.id == action.plot_id:
            plot = p
            break
    if not plot:
        return
    match action.action_type:
        CareAction.PLANT:
            if not plot.is_occupied and _templates.has(action.reference_id):
                plot.plant(PlantedFlower.new(action.reference_id, user_id))
        CareAction.WATER, CareAction.FERTILIZE, CareAction.PESTICIDE:
            if plot.is_occupied and _consumables.has(action.reference_id):
                var xp: int = _consumables[action.reference_id]["received_exp"]
                plot.current_plant.current_xp += xp
                if _templates.has(plot.current_plant.flower_template_id):
                    var tmpl: FlowerTemplate = _templates[plot.current_plant.flower_template_id]
                    plot.current_plant.current_stage = tmpl.compute_stage_for_xp(plot.current_plant.current_xp)
        CareAction.HARVEST:
            if plot.is_occupied:
                plot.clear()
```

---

## ItemData Resource (Godot)

```gdscript
# ItemData.gd
class_name ItemData
extends Resource

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var plant_scene: PackedScene  # for seeds only, null otherwise
@export var category: int             # 0=Seed, 1=Consumable, 2=Decor, 3=HarvestProduct
@export var consumable_type: int      # 0=Water, 1=Fertilizer, 2=Pesticide
@export var received_exp: int
```

Create one `.tres` file per item:

| File | id | received_exp | category |
|------|----|-------------|----------|
| `item_water.tres` | `item_water` | 20 | 1 (Consumable) |
| `item_fertilizer.tres` | `item_fertilizer` | 50 | 1 (Consumable) |
| `item_pesticide.tres` | `item_pesticide` | 50 | 1 (Consumable) |
| `flower_sunflower.tres` | `flower_sunflower` | 0 | 0 (Seed) |
| `flower_rose.tres` | `flower_rose` | 0 | 0 (Seed) |

---

## ExpBar Scene (Godot)

```gdscript
# ExpBarView.gd
extends CanvasLayer  # or Control, depending on placement

@onready var level_label:    Label       = $LevelLabel
@onready var fill_bar:       ProgressBar = $ProgressGroup/FillBar
@onready var xp_label:       Label       = $XpLabel
@onready var progress_group: Control     = $ProgressGroup
@onready var max_badge:      Control     = $MaxBadge

func refresh(plant: PlantedFlower, template: FlowerTemplate) -> void:
    if not plant or not template:
        hide()
        return
    show()

    var current_stage: int = template.compute_stage_for_xp(plant.current_xp)
    var max_stage: int     = template.get_max_stage_level()
    var prev_xp: int       = template.get_xp_required_for_stage(current_stage)
    var next_xp: int       = template.get_next_stage_xp(current_stage)

    level_label.text = "Lv.%d" % current_stage

    var at_max: bool = current_stage >= max_stage or next_xp < 0
    if at_max:
        progress_group.hide()
        max_badge.show()
        fill_bar.value  = 100.0
        xp_label.text   = "MAX"
        return

    progress_group.show()
    max_badge.hide()
    var span: int  = max(1, next_xp - prev_xp)
    var into: int  = clamp(plant.current_xp - prev_xp, 0, span)
    fill_bar.value = float(into) / float(span) * 100.0
    xp_label.text  = "%d / %d" % [plant.current_xp, next_xp]
```

---

## Key Migration Rules

| Rule | Why |
|------|-----|
| Optimistic UI — always local predict first | Users expect instant feedback; no spinners on mobile |
| `is_pending_sync` guard on every plot | Prevents race conditions from rapid swipe gestures |
| Stage is always computed from XP | Never trust or store a client-sent stage value |
| Harvest requires `current_stage >= max_stage` | Guard before clearing the plot |
| `LocalGrantHarvestItem` creates a new entry | HarvestProducts don't exist in inventory until first harvest |
| All UI updates go through signals | Never call a View method directly from a Manager |
