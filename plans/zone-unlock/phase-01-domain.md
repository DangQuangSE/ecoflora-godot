# Phase 01 — Domain: ZoneDefinition

**Layer:** domain/
**Testing:** skipped (--no-test)
**Spec stories covered:** FR-01

---

## Goal

Create a pure data class `ZoneDefinition` in `domain/` that holds all metadata for a single zone. No Node, no autoload imports, no side effects.

---

## Files

| File | Layer | Action |
|------|-------|--------|
| `domain/ZoneDefinition.gd` | domain | CREATE |

---

## Steps

### 1. Create `domain/ZoneDefinition.gd`

```gdscript
class_name ZoneDefinition
extends RefCounted

var zone_id: String = ""
var required_level: int = 1
var plot_ids: Array[String] = []       # e.g. ["plot_8","plot_9","plot_10","plot_11"]
var world_position: Vector2 = Vector2.ZERO

static func create(
		id: String,
		level_req: int,
		ids: Array[String],
		pos: Vector2) -> ZoneDefinition:
	var z := ZoneDefinition.new()
	z.zone_id = id
	z.required_level = level_req
	z.plot_ids = ids
	z.world_position = pos
	return z
```

**Note:** `plot_ids` uses the same `"plot_N"` string scheme used by `GardenManager`, `InteractionManager`, and all existing domain code — NOT integer indices.

### 2. Verify

- No `extends Node` — ✓ extends RefCounted
- No `get_tree()`, `$child`, `get_node()` — ✓
- No `print()` — ✓
- No autoload imports — ✓

---

## Success Criteria

- [ ] `domain/ZoneDefinition.gd` exists with `class_name ZoneDefinition`
- [ ] `plot_ids` is `Array[String]` (not int)
- [ ] Static factory `create()` returns a populated instance
- [ ] File passes `godot --headless --check-only --script res://domain/ZoneDefinition.gd`
