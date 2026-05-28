# Plan: Garden System — Full Loop (Plant → Grow → Harvest)

**Date:** 2026-05-26
**Status:** Complete
**Spec:** plans/garden-system/spec.md
**Branch:** feat/migrate-function

---

## Overview

Build the core gameplay loop for Flow Flora: 8 garden plots in GardenScene, player plants seeds from inventory, flower grows through XP-based stages (with debug XP button for demo), player harvests at max stage to receive product. Uses Clean Architecture: services → autoloads → scenes.

Domain classes (Plot, PlantedFlower, FlowerTemplate, etc.) **already exist** — no changes needed there.

---

## Phases

- [x] **Phase 01 — Mock Services** (`services/`) — MockGardenService + MockInventoryService
- [x] **Phase 02 — Autoloads** (`autoloads/`) — GardenManager + InventoryManager + InteractionManager stub
- [x] **Phase 03 — Plot Scene** (`scenes/garden/`) — Plot.tscn + Plot.gd with proximity popup
- [x] **Phase 04 — GardenScene Integration** (`scenes/garden/`) — 8 plots spawned, full loop wired

---

## Architecture Flow

```
MockGardenService.gd    ← services/ (domain only)
MockInventoryService.gd ← services/ (domain only)
       ↓
GardenManager.gd        ← autoloads/ (imports domain + services)
InventoryManager.gd     ← autoloads/ (imports domain + services)
       ↓
Plot.gd / Plot.tscn     ← scenes/ (imports autoloads + domain)
GardenScene.gd          ← scenes/ (imports autoloads + domain)
```

---

## Risks

- **Plot positioning**: 8 plots need world positions inside TileMap bounds — hardcode as constants in GardenManager for now, move to @export array later.
- **project.godot autoloads MISSING**: GardenManager, InventoryManager, InteractionManager are NOT yet registered in project.godot (only SceneTransition is). Phase 02 must add all 3 entries via the Godot Editor (Project → Project Settings → Autoload tab) or direct text edit of project.godot.
- **is_pending_sync race**: Optimistic UI pattern required for all write ops — must set before await, clear after (success or rollback).
- **await Engine.get_main_loop().process_frame**: Valid in Godot 4 for 1-frame defer — confirms mock async pattern works without a real service.

---

## Cook Command

```
/ck:cook plans/garden-system/plan.md
```
