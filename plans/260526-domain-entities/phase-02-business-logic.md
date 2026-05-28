# Phase 2: Business Logic Entities

## Layer
Domain

## Files

| File | Layer | Depends On |
|------|-------|------------|
| `domain/FlowerTemplate.gd` | Domain | `StageDefinition` (Phase 1) |
| `domain/InventoryItem.gd` | Domain | nothing |
| `domain/UserInventory.gd` | Domain | `InventoryItem` (this phase — write InventoryItem first) |

> Phase ordering: `InventoryItem.gd` MUST be written before `UserInventory.gd`. `StageDefinition.gd` from Phase 1 MUST exist before this phase begins.

## Requirements

Write the three domain classes that encode all flower-growth computation and inventory lookup logic. After this phase the domain layer is complete and autoloads can resolve flower stages and find inventory entries purely through domain objects, with no service calls needed.

## Exact Code

### domain/FlowerTemplate.gd

```gdscript
class_name FlowerTemplate
extends RefCounted

var id: String
var name: String
var base_price: int
var image_url: String
var synergy_id: String
var harvest_product_id: String
var stages: Array[StageDefinition] = []

func get_max_stage_level() -> int:
	var max_level := 1
	for s: StageDefinition in stages:
		if s.level > max_level:
			max_level = s.level
	return max_level

func compute_stage_for_xp(current_xp: int) -> int:
	if stages.is_empty():
		return 1
	# Sort ascending by xp_required so the loop is order-independent.
	var sorted := stages.duplicate()
	sorted.sort_custom(func(a: StageDefinition, b: StageDefinition) -> bool:
		return a.xp_required < b.xp_required)
	var best_level: int = sorted[0].level
	var best_xp: int    = sorted[0].xp_required
	for s: StageDefinition in sorted:
		if s.xp_required <= current_xp and s.xp_required >= best_xp:
			best_level = s.level
			best_xp    = s.xp_required
	return best_level

func get_xp_required_for_stage(level: int) -> int:
	for s: StageDefinition in stages:
		if s.level == level:
			return s.xp_required
	return 0

func get_next_stage_xp(current_stage: int) -> int:
	if current_stage >= get_max_stage_level():
		return -1
	var next_level := 999999
	var next_xp    := -1
	for s: StageDefinition in stages:
		if s.level > current_stage and s.level < next_level:
			next_level = s.level
			next_xp    = s.xp_required
	return next_xp
```

### domain/InventoryItem.gd

```gdscript
class_name InventoryItem
extends RefCounted

enum Category { SEED = 0, CONSUMABLE = 1, DECOR = 2, HARVEST_PRODUCT = 3 }

var id: String
var inventory_id: String
var flower_template_id: String
var item_id: String
var decor_id: String
var harvest_product_id: String
var quantity: int
var category: int  # Category enum value

func get_reference_id() -> String:
	match category:
		Category.SEED:            return flower_template_id
		Category.CONSUMABLE:      return item_id
		Category.DECOR:           return decor_id
		Category.HARVEST_PRODUCT: return harvest_product_id
		_:
			push_error("InventoryItem.get_reference_id: unknown category %d for item %s" % [category, id])
			return ""
```

### domain/UserInventory.gd

```gdscript
class_name UserInventory
extends RefCounted

var id: String
var user_id: String
var current_slots: int
var items: Array[InventoryItem] = []

func find_by_id(entry_id: String) -> InventoryItem:
	for item: InventoryItem in items:
		if item.id == entry_id:
			return item
	return null

func find_by_reference_id(ref_id: String) -> InventoryItem:
	if ref_id.is_empty():
		return null
	for item: InventoryItem in items:
		if item.get_reference_id() == ref_id:
			return item
	return null

func find_harvest_product(harvest_product_id: String) -> InventoryItem:
	for item: InventoryItem in items:
		if item.category == InventoryItem.Category.HARVEST_PRODUCT \
				and item.harvest_product_id == harvest_product_id:
			return item
	return null
```

## Done When

- [ ] `domain/FlowerTemplate.gd` exists with all 4 methods
- [ ] `compute_stage_for_xp(50)` on Sunflower template (stages: 1→0, 4→100, 7→300) returns `1`
- [ ] `compute_stage_for_xp(100)` returns `4`; `compute_stage_for_xp(300)` returns `7`
- [ ] `get_next_stage_xp(7)` on Sunflower returns `-1` (early-return guard)
- [ ] `get_next_stage_xp(4)` on Sunflower returns `300`
- [ ] `domain/InventoryItem.gd` has `Category` enum, all 6 `String` fields, `quantity: int`, `category: int`, `get_reference_id()` calls `push_error` on unknown category
- [ ] `domain/UserInventory.gd` has typed `Array[InventoryItem]`, all 3 find-helpers return `null` when not found, `find_by_reference_id` returns `null` on empty-string input
- [ ] No file in `domain/` contains `Node`, `get_tree`, `$`, `add_child`, any autoload name, or `print()`
