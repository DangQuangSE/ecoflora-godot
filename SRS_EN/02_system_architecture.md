# 02 — System Architecture

## High-Level Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Mobile Game Client                    │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │              Presentation Layer                  │   │
│  │  Views, Presenters, UI Controllers, HarvestBtn   │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │ events / calls                    │
│  ┌──────────────────▼───────────────────────────────┐   │
│  │              Application Layer                   │   │
│  │  GardenManager, InventoryManager,                │   │
│  │  InteractionManager, UseCases                    │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │ domain objects                    │
│  ┌──────────────────▼───────────────────────────────┐   │
│  │               Domain Layer                       │   │
│  │  Plot, PlantedFlower, FlowerTemplate,            │   │
│  │  CareAction, InventoryItem, ItemCategory         │   │
│  └──────────────────┬───────────────────────────────┘   │
│                     │ interfaces                        │
│  ┌──────────────────▼───────────────────────────────┐   │
│  │            Infrastructure Layer                  │   │
│  │  MockGardenService, MockInventoryService,        │   │
│  │  ItemCatalogSO, ItemDataSO                       │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                           │
                     REST API calls
                           │
┌──────────────────────────▼──────────────────────────────┐
│                   Backend API Server                    │
│           (Spring Boot / Node.js — not yet live)        │
└─────────────────────────────────────────────────────────┘
```

---

## Clean Architecture — 4 Layers

### Layer 1: Domain
- **Purpose**: Pure business entities with no framework dependencies
- **Components**:
  - `Plot` — a garden plot tile
  - `PlantedFlower` — a live flower instance owned by a user
  - `FlowerTemplate` — master data for a flower species
  - `CareAction` — a care action (PLANT/WATER/…)
  - `InventoryItem` — an item in the user's bag
  - `ItemCategory` enum — Seed, Consumable, Decor, HarvestProduct
  - `StageDefinition` — XP threshold for each growth stage

### Layer 2: Application
- **Purpose**: Orchestrate use cases, hold in-memory state, expose events
- **Components**:
  - `GardenManager` (Singleton) — plant/care/harvest with optimistic UI
  - `InventoryManager` (Singleton) — manage inventory + item catalog
  - `InteractionManager` (Singleton) — track mode (Planting/UsingConsumable/Harvesting)
  - `GetGardenStateUseCase` — load plots from service
  - `SyncBatchActionsUseCase` — send care actions to server
  - `UseItemUseCase` — consume an item from inventory

### Layer 3: Infrastructure
- **Purpose**: Implement interfaces, connect to data sources
- **Components**:
  - `MockGardenService` — simulates server with 50ms delay
  - `MockInventoryService` — simulates inventory server
  - `ItemCatalogSO` — ScriptableObject holding all `ItemDataSO` entries
  - `ItemDataSO` — ScriptableObject per item (icon, prefab, xp, …)

### Layer 4: Presentation
- **Purpose**: Unity MonoBehaviours, UI rendering, user input
- **Components**:
  - `PlotView` — renders one plot tile, spawns plant prefab
  - `PlantView` — renders the plant, forwards state to ExpBar
  - `PlantExpBarView` — world-space XP bar above the plant
  - `GardenPresenter` — listens to GardenManager events, refreshes PlotViews
  - `InventoryView` — bag UI, displays items
  - `HarvestToolButton` — button to activate Harvest mode
  - `SwipeInteractionHandler` — receives swipe input, forwards to managers

---

## Key Patterns

### Optimistic UI Pattern
Every write operation (plant/water/harvest) follows this pipeline:
1. **Local predict** — apply change to local state immediately
2. **UI refresh** — update UI right away (user sees result instantly, no spinner)
3. **Background sync** — call mock/real service asynchronously
4. **On success** — update state with server response
5. **On failure** — ROLLBACK to previous state + UI refresh

```
User action
    ↓
[Local predict] → UI updates immediately (no spinner)
    ↓
[Async service call] (50ms mock delay)
    ↓ success              ↓ failure
[Update from server]    [Rollback + UI refresh]
```

### IsPendingSync Guard
Each `Plot` has an `IsPendingSync` flag. While a sync is pending, new actions on the same plot are rejected. This prevents race conditions.

### Singleton Managers
`GardenManager`, `InventoryManager`, and `InteractionManager` are all Singleton MonoBehaviours. Access via the `.Instance` property.

---

## Module Structure (Unity namespace)

```
EcoGame
├── Garden
│   ├── Domain.Entities     (Plot, PlantedFlower, FlowerTemplate, CareAction)
│   ├── Domain.Services     (IGardenService interface)
│   ├── Application.Managers (GardenManager, InteractionManager)
│   ├── Application.UseCases (GetGardenStateUseCase, SyncBatchActionsUseCase)
│   ├── Infrastructure.Services_MockData (MockGardenService)
│   └── Presentation
│       ├── Views           (PlotView, PlantView, PlantExpBarView, HarvestToolButton)
│       ├── Presenters      (GardenPresenter)
│       └── Interaction     (SwipeInteractionHandler)
└── Inventory
    ├── Domain.Entities     (InventoryItem, Item, ItemCategory, UserInventory)
    ├── Domain.Interfaces   (IInventoryService)
    ├── Application.Managers (InventoryManager)
    ├── Application.UseCases (UseItemUseCase)
    ├── Infrastructure.Data (ItemCatalogSO, ItemDataSO)
    ├── Infrastructure.Services (MockInventoryService)
    └── Presentation.Views  (InventoryView)
```

---

## Godot Equivalent Structure

```
flow_flora_godot/
├── src/
│   ├── domain/
│   │   ├── plot.gd
│   │   ├── planted_flower.gd
│   │   ├── flower_template.gd
│   │   ├── care_action.gd
│   │   └── inventory_item.gd
│   ├── application/
│   │   ├── garden_manager.gd      (Autoload singleton)
│   │   ├── inventory_manager.gd   (Autoload singleton)
│   │   └── interaction_manager.gd (Autoload singleton)
│   ├── infrastructure/
│   │   ├── mock_garden_service.gd
│   │   └── mock_inventory_service.gd
│   └── presentation/
│       ├── plot_view.gd
│       ├── plant_view.gd
│       ├── exp_bar_view.gd
│       └── inventory_view.gd
└── assets/
```
