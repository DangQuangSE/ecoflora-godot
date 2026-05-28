# Plan: Domain Layer — Remaining 6 Entity Files

Status: Done
Date: 2026-05-26
Mode: Hard, --no-test

## Overview

Implement the six remaining domain entity files that complete the bottom layer of Flow & Flora's Clean Architecture stack. All files extend `RefCounted`, contain zero Node or autoload references, and expose the exact GDScript API required by the mock services and autoloads above them.

## Goals

- Provide a fully self-contained domain layer (no upward imports).
- Encode all flower-growth business logic inside `FlowerTemplate` (`compute_stage_for_xp`, `get_next_stage_xp`, etc.).
- Give `UserInventory` the three find-helpers needed by `InventoryManager`.
- Give `CareAction` the five action-type constants used by `InteractionManager`.

## Layers Touched

- **domain/** only — no other layer is modified.

## Phases

| # | Name | Files | Summary |
|---|------|-------|---------|
| 1 | Foundational Entities | StageDefinition, CareAction, PlantedFlower | Zero cross-entity deps; safe to write first |
| 2 | Business Logic Entities | FlowerTemplate, InventoryItem, UserInventory | Depend on Phase 1; contain all computation logic |

- [x] Phase 1: Foundational Entities
- [x] Phase 2: Business Logic Entities

## Key Rules (from CLAUDE.md)

- All domain classes MUST extend `RefCounted`. NEVER extend `Node`.
- NEVER import or reference autoloads (`GardenManager`, `InventoryManager`, `InteractionManager`).
- NEVER call `get_tree()`, `$children`, `add_child()`, or any Node API.
- NEVER use `print()` — use `push_warning()` / `push_error()` if logging is needed.
- `snake_case` for all variables and function names.
- `PascalCase` for all `class_name` declarations.
- Type hints on ALL function parameters and return types.
- Signals are NOT defined in domain classes.
- `@export` is NOT used in domain classes.

## Red-Team Findings Applied

1. **ID generation** — replaced `randi()` with `Time.get_ticks_usec()` + static counter to guarantee session-unique IDs.
2. **stages array ordering** — `compute_stage_for_xp` must sort `stages` ascending by `xp_required` before iterating.
3. **get_next_stage_xp guard** — add early-return `if current_stage >= get_max_stage_level(): return -1`.
4. **get_reference_id() empty string** — add `push_error` on unknown category; `find_by_reference_id` returns null immediately if search key is `""`.
5. **deep_copy side-effect** — `PlantedFlower.deep_copy()` must NOT call `PlantedFlower.new(...)` with args that trigger _init side-effects; assign every field explicitly.
6. **Typed arrays** — `stages: Array[StageDefinition]` and `items: Array[InventoryItem]` (Godot 4 typed arrays).
7. **category silent fail** — `get_reference_id()` else branch calls `push_error()`.

## Risks

- NOTED: `current_xp` is unclamped — if server sends a value far above max, `compute_stage_for_xp` correctly returns max stage, but `xpLabel` may briefly display an unexpected value. Clamping is handled by the Application layer, not domain.
- LOW: `Array[StageDefinition]` typed array enforcement requires Godot 4.1+. Project targets Godot 4.x; confirmed safe.
