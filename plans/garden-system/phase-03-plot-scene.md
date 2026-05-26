# Phase 03 — Plot Scene

## Layer
`scenes/garden/` — imports `autoloads/` + `domain/`. Node-based UI.

## Files

| File | Path | Action | Layer |
|------|------|--------|-------|
| Plot.gd | res://scenes/garden/Plot.gd | NEW | scenes |
| Plot.tscn | res://scenes/garden/Plot.tscn | NEW | scenes |

## User Stories Covered
- US-02 (proximity popup), US-03 (plant button), US-05 (stage visual), US-06 (harvest button)

## Scene Tree (Plot.tscn)

```
Plot (Node2D) [Plot.gd]
├── PlotSprite (ColorRect)       ← placeholder visual, size 64×64
├── StageLabel (Label)           ← "Lv.X" centered above sprite
├── Popup (CanvasLayer)
│   ├── BtnPlant (Button)        ← "Plant"
│   ├── BtnHarvest (Button)      ← "Harvest"
│   ├── BtnAddXP (Button)        ← "Debug +XP" (demo only)
│   └── SeedOptions (VBoxContainer)
│       ├── BtnSunflower (Button) ← "🌻 Sunflower"
│       └── BtnRose (Button)      ← "🌹 Rose"
```

## Implementation Steps

### Plot.gd

```gdscript
class_name PlotNode
extends Node2D

@export var plot_id: String = ""
@export var proximity_radius: float = 80.0

@onready var plot_sprite: ColorRect = $PlotSprite
@onready var stage_label: Label = $StageLabel
@onready var popup: CanvasLayer = $Popup
@onready var btn_plant: Button = $Popup/BtnPlant
@onready var btn_harvest: Button = $Popup/BtnHarvest
@onready var btn_add_xp: Button = $Popup/BtnAddXP
@onready var seed_options: VBoxContainer = $Popup/SeedOptions

var _player_ref: Node2D = null
var _current_plot: Plot = null

# Stage colors for placeholder visual
const STAGE_COLORS := {
    0: Color(0.6, 0.4, 0.2),   # empty — brown dirt
    1: Color(0.4, 0.8, 0.2),   # sprout — light green
    4: Color(0.1, 0.6, 0.1),   # bud — dark green
    7: Color(1.0, 0.9, 0.0),   # bloom — gold/yellow (harvest ready)
}

func setup(plot: Plot, player: Node2D) -> void:
    plot_id = plot.id
    _current_plot = plot
    _player_ref = player
    _refresh_visual()

func update_plot(plot: Plot) -> void:
    _current_plot = plot
    _refresh_visual()

func _process(_delta: float) -> void:
    if _player_ref == null:
        return
    var in_range := global_position.distance_to(_player_ref.global_position) <= proximity_radius
    popup.visible = in_range

func _refresh_visual() -> void:
    if _current_plot == null:
        return
    var stage := 0
    if _current_plot.is_occupied and _current_plot.current_plant != null:
        stage = _current_plot.current_plant.current_stage

    var color_key := 0
    if stage >= 7:   color_key = 7
    elif stage >= 4: color_key = 4
    elif stage >= 1: color_key = 1
    plot_sprite.color = STAGE_COLORS.get(color_key, STAGE_COLORS[0])

    if _current_plot.is_occupied:
        stage_label.text = "Lv.%d" % stage
        stage_label.visible = true
    else:
        stage_label.visible = false

    var is_harvest_ready := _current_plot.is_occupied and stage >= 7
    btn_plant.visible = not _current_plot.is_occupied
    btn_harvest.visible = is_harvest_ready
    btn_add_xp.visible = _current_plot.is_occupied and not is_harvest_ready
    seed_options.visible = false

func _on_btn_plant_pressed() -> void:
    seed_options.visible = not seed_options.visible

func _on_btn_sunflower_pressed() -> void:
    if InventoryManager.has_seed("sunflower"):
        InventoryManager.consume_seed("sunflower")
        InteractionManager.request_plot_action(plot_id, "plant", {"template_id": "sunflower"})
    seed_options.visible = false

func _on_btn_rose_pressed() -> void:
    if InventoryManager.has_seed("rose"):
        InventoryManager.consume_seed("rose")
        InteractionManager.request_plot_action(plot_id, "plant", {"template_id": "rose"})
    seed_options.visible = false

func _on_btn_harvest_pressed() -> void:
    InteractionManager.request_plot_action(plot_id, "harvest")

func _on_btn_add_xp_pressed() -> void:
    InteractionManager.request_plot_action(plot_id, "add_xp", {"amount": 150})
```

## Acceptance Test

- Plot node added to GardenScene, player walks within 80px → popup appears
- Empty plot: shows BtnPlant only; click Plant → SeedOptions appears
- After planting: PlotSprite turns green, StageLabel shows "Lv.1"
- Click Debug +XP twice: stage advances (Lv.1 → Lv.4 → Lv.7), color changes
- At Lv.7: BtnHarvest visible, BtnAddXP hidden; click Harvest → plot resets to brown/empty
