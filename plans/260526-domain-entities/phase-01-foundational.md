# Phase 1: Foundational Entities

## Layer
Domain

## Files

| File | Layer | Depends On |
|------|-------|------------|
| `domain/StageDefinition.gd` | Domain | nothing |
| `domain/CareAction.gd` | Domain | nothing |
| `domain/PlantedFlower.gd` | Domain | nothing |

> Phase ordering: StageDefinition MUST be written before FlowerTemplate (Phase 2). PlantedFlower MUST be written before Plot usages in Phase 2. Both are satisfied by completing this phase in full before Phase 2 begins.

## Requirements

Write the three domain classes that have zero dependencies on other domain entities in this plan. After this phase the domain layer can represent:
- One XP growth stage threshold (`StageDefinition`)
- One care action sent to the server (`CareAction`)
- One live flower instance inside a plot (`PlantedFlower`)

## Exact Code

### domain/StageDefinition.gd

```gdscript
class_name StageDefinition
extends RefCounted

var level: int
var xp_required: int
var model_key: String
```

### domain/CareAction.gd

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

static var _counter: int = 0

func _init(pid: String = "", atype: String = "", ref_id: String = "") -> void:
	CareAction._counter += 1
	action_id    = "%d_%d" % [Time.get_ticks_usec(), CareAction._counter]
	plot_id      = pid
	action_type  = atype
	reference_id = ref_id
	timestamp    = int(Time.get_unix_time_from_system())
```

### domain/PlantedFlower.gd

```gdscript
class_name PlantedFlower
extends RefCounted

static var _counter: int = 0

var id: String
var flower_template_id: String
var user_id: String
var current_xp: int = 0
var current_stage: int = 1
var planted_at: int = 0
var last_watered_at: int = 0
var last_fertilized_at: int = 0

func _init(template_id: String = "", uid: String = "") -> void:
	PlantedFlower._counter += 1
	id                 = "%d_%d" % [Time.get_ticks_usec(), PlantedFlower._counter]
	flower_template_id = template_id
	user_id            = uid
	current_xp         = 0
	current_stage      = 1
	planted_at         = int(Time.get_unix_time_from_system())
	last_watered_at    = 0
	last_fertilized_at = 0

func deep_copy() -> PlantedFlower:
	var copy := PlantedFlower.new()
	copy.id                 = id
	copy.flower_template_id = flower_template_id
	copy.user_id            = user_id
	copy.current_xp         = current_xp
	copy.current_stage      = current_stage
	copy.planted_at         = planted_at
	copy.last_watered_at    = last_watered_at
	copy.last_fertilized_at = last_fertilized_at
	return copy
```

> **deep_copy note:** calls `PlantedFlower.new()` with NO args to bypass `_init` side-effects (ticks-based ID + timestamp). Every field is then assigned explicitly, so the copy is a true snapshot of the source.

## Done When

- [ ] `domain/StageDefinition.gd` exists with `class_name StageDefinition`, extends `RefCounted`, declares `level: int`, `xp_required: int`, `model_key: String`
- [ ] `domain/CareAction.gd` exists with all 5 action-type `const`, all 5 typed instance variables, `_init` sets `action_id` via ticks+counter, sets `timestamp` via `Time.get_unix_time_from_system()`
- [ ] `domain/PlantedFlower.gd` exists with ticks+counter `id` generation in `_init`, `deep_copy()` uses no-arg constructor and assigns all 8 fields explicitly
- [ ] None of the three files contain `Node`, `get_tree`, `$`, `add_child`, any autoload name, or `print()`
