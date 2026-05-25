# Flow & Flora — System Requirements Specification (SRS)

> **Purpose:** This document describes the complete Flow & Flora system so that any developer (including on other platforms such as Godot) can fully understand and re-implement it.

## Table of Contents

| File | Contents |
|------|----------|
| [01_project_overview.md](01_project_overview.md) | Project overview, core gameplay loop, feature list |
| [02_system_architecture.md](02_system_architecture.md) | System architecture, layers, patterns |
| [03_database_schema.md](03_database_schema.md) | Full 13-table schema with relationships |
| [04_garden_system.md](04_garden_system.md) | Garden module: plot, flower, XP, stage progression |
| [05_inventory_system.md](05_inventory_system.md) | Inventory module: items, categories, seeds, consumables |
| [06_interaction_flows.md](06_interaction_flows.md) | Interaction modes & user input flows |
| [07_gameplay_mechanics.md](07_gameplay_mechanics.md) | Gameplay data: XP values, stage thresholds, cooldowns, mock data |
| [08_focus_system.md](08_focus_system.md) | Focus Mode (study concentration mode) |
| [09_godot_migration.md](09_godot_migration.md) | Guide for porting to Godot / GDScript |

## Current Tech Stack (Unity)

- **Engine:** Unity 6, URP 17.3.0
- **Platform:** Mobile, 2D Portrait
- **Language:** C# (.NET)
- **Architecture:** Clean Architecture 4-layer
- **Backend API:** REST (local mock in MVP)

## MVP Status

| Feature | Status |
|---------|--------|
| Garden (plant/water/fertilize/pesticide/harvest) | ✅ Done |
| Inventory (seeds + consumables + harvest products) | ✅ Done |
| XP + Stage progression | ✅ Done |
| Optimistic UI + Rollback | ✅ Done |
| Harvest system | ✅ Done |
| Focus Mode | 🔲 Planned |
| Weather API | 🔲 Planned |
| GPS Check-in | 🔲 Planned |
| Synergy system | 🔲 Planned |
| Daily quests | 🔲 Planned |
