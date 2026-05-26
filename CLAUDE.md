# CLAUDE.md — Flow Flora (Godot 4 / GDScript)

## Project

Mobile garden game. 2D Portrait. Godot 4.x, GDScript only (no C#).
Full system spec: see `docs/SRS_EN/` folder.

## Commands

```bash
# Run game (headless, no window — for script testing)
godot --headless --script res://tools/run_tests.gd

# Export (after export template installed)
godot --headless --export-release "Android" builds/flow_flora.apk

# Check for GDScript errors (static analysis)
godot --headless --check-only --script res://autoloads/GardenManager.gd
```

## Architecture

Clean Architecture 4 layers — strictly NO upward imports:

```
domain/        ← RefCounted classes, no Node, no autoload imports
services/      ← mock + real API, imports domain only
autoloads/     ← Singletons (GardenManager, InventoryManager, InteractionManager, UserManager)
scenes/        ← Nodes/Controls, imports autoloads and domain
```

Autoloads registered in project.godot:

- `GardenManager` → res://autoloads/GardenManager.gd
- `InventoryManager` → res://autoloads/InventoryManager.gd
- `InteractionManager` → res://autoloads/InteractionManager.gd
- `UserManager` → res://autoloads/UserManager.gd (must load AFTER GardenManager)

## Code Style

- `snake_case` for variables, functions, files
- `PascalCase` for class_name
- Type hints on ALL function parameters and return types
- `@export` for Inspector-configurable values
- Signals defined at top of class, before variables
- No `print()` in production — use `push_warning()` / `push_error()`

## GDScript Patterns

### Optimistic UI (REQUIRED for all write ops)

```gdscript
func optimistic_action(plot_id: String) -> void:
	var plot := get_plot(plot_id)
	if not plot or plot.is_pending_sync:
		return
	# 1. Local predict
	plot.is_pending_sync = true
	# ... mutate local state ...
	some_signal.emit(current_data)
	# 2. Async sync
	var result = await mock_service.sync_async(...)
	if result != null:
		plot.is_pending_sync = false
		current_data = result
		some_signal.emit(current_data)
	else:
		# 3. Rollback
		plot.is_pending_sync = false
		# ... restore state ...
		some_signal.emit(current_data)
```

### Domain classes (no Node)

```gdscript
class_name Plot
extends RefCounted
# Never extend Node, never use $children, never call get_tree()
```

### Async calls

```gdscript
# Always use await, never yield (deprecated)
var result = await service.get_data_async()
```

## Key Rules

- Never trust client-sent stage — always compute from XP via `compute_stage_for_xp()`
- `is_pending_sync` must be set before any async call and cleared after (success or failure)
- HarvestProduct inventory entries must be created if they don't exist (unlike seeds/consumables)
- All UI updates go through signals, never direct Manager→View calls

## Mock Data (for reference)

- Sunflower: stages Lv1=0xp, Lv4=100xp, Lv7=300xp | harvest: harvest_sunflower_bloom
- Rose: stages Lv1=0xp, Lv4=120xp, Lv7=360xp | harvest: harvest_rose_bloom
- Water: +20 XP, 3600s cooldown
- Fertilizer: +50 XP, 7200s cooldown
- Pesticide: +50 XP, 7200s cooldown
