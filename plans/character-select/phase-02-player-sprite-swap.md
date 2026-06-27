# Phase 02 — Player: set_character(idx) + GardenScene wiring

**Goal:** `Player.gd` accepts a character index and swaps SpriteFrames at runtime.

**Covers:** FR-02 | **Dependencies:** Assets exist at `res://assets/characters/`

---

## Files

| File | Change |
|------|--------|
| `scenes/shared/Player.gd` | +const `_CHARACTER_FRAMES`, +`set_character()` |
| `scenes/garden/GardenScene.gd` | Call `set_character()` in `_ready()` |

---

## Steps

**1. `Player.gd`** — add after existing constants, before `@onready` vars:

```gdscript
const _CHARACTER_FRAMES: Array = [
	preload("res://assets/characters/char_0.tres"),
	preload("res://assets/characters/char_1.tres"),
]
```

Add as a public method (after `_ready`):

```gdscript
func set_character(idx: int) -> void:
	var clamped := clampi(idx, 0, _CHARACTER_FRAMES.size() - 1)
	_sprite.sprite_frames = _CHARACTER_FRAMES[clamped]
	if not _sprite.sprite_frames.has_animation(_sprite.animation):
		_sprite.play("idle_down")
```

**2. `GardenScene.gd`** — in `_ready()`, after `_player` node is ready, add:

```gdscript
_player.set_character(UserManager.get_character_index())
```

Place this after any existing `_player` setup calls (e.g. after `_player.set_input_enabled(true)` or similar). If `UserManager.get_character_index()` doesn't exist yet (Phase 3), stub it to return `0` for now.

---

## Asset Requirements

Each `.tres` (SpriteFrames resource) must define exactly these animations with the same frame sizes as the default character:

```
idle_down   idle_up
walk_right  walk_left  walk_down  walk_up
```

Validate at import time: open each `.tres` in the Godot editor and confirm all 6 animation names appear in the SpriteFrames panel before cooking Phase 2.

---

## Acceptance Check

- `Player.set_character(0)` → default sprite, all 6 animations play
- `Player.set_character(1)` → new sprite, all 6 animations play without errors
- `Player.set_character(99)` → clamped to last index, no crash
- GardenScene loads player with correct character (index 0 until Phase 3 is wired)
