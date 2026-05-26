# Phase 04 — GardenScene Integration

## Layer
`scenes/garden/` — connects autoloads to Plot nodes, wires full loop.

## Files

| File | Path | Action | Layer |
|------|------|--------|-------|
| GardenScene.gd | res://scenes/garden/GardenScene.gd | UPDATE | scenes |

## User Stories Covered
- US-01 (8 plots visible), US-03 (plant), US-05 (stage visual), US-06 (harvest), US-07 (inventory update)

## Implementation Steps

### GardenScene.gd additions

```gdscript
# Add these to existing GardenScene.gd (keep joystick + camera logic)

const PlotScene := preload("res://scenes/garden/Plot.tscn")

@onready var player: CharacterBody2D = $Player

var _plot_nodes: Array[PlotNode] = []

func _ready() -> void:
    # existing camera setup code stays here ...
    _spawn_plots()
    GardenManager.plots_updated.connect(_on_plots_updated)

func _spawn_plots() -> void:
    var plots := GardenManager.get_plots()
    for i in range(plots.size()):
        var node: PlotNode = PlotScene.instantiate()
        add_child(node)
        node.global_position = GardenManager.get_plot_position(i)
        node.setup(plots[i], player)
        _plot_nodes.append(node)

func _on_plots_updated(plots: Array[Plot]) -> void:
    for i in range(min(plots.size(), _plot_nodes.size())):
        _plot_nodes[i].update_plot(plots[i])
```

## Acceptance Test

- Open GardenScene in editor → 8 PlotNode children visible at expected positions
- Run game: player can walk to any plot, popup appears
- Full loop works end-to-end:
  1. Start: 3× sunflower_seed in InventoryManager
  2. Plant sunflower in plot_0 → seed count drops to 2, plot shows Lv.1 green
  3. Debug +XP × 2 → plot shows Lv.4 then Lv.7 (gold), BtnHarvest appears
  4. Harvest → plot clears to brown, harvest_sunflower_bloom count = 1 in InventoryManager
  5. GardenManager.plots_updated signal fires after each action — no stale state

## Definition of Done

- All 4 phases complete
- Full loop playable in GardenScene without editor errors
- No print() in any new file — push_warning()/push_error() only
- Architecture rule verified: no upward imports (domain ← services ← autoloads ← scenes)
