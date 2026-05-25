# 04 — Garden System

## Overview

The Garden System manages the complete lifecycle of a flower: planting → caring → harvesting. This is the core module of the game.

---

## Entities

### Plot
One plot tile in the garden. The grid is 3×3 = 9 tiles.

```
id:             "plot_0" .. "plot_8"
gardenId:       "garden_default"
plotIndex:      0 .. 8
isOccupied:     bool
isPendingSync:  bool   ← guard flag, prevents duplicate concurrent actions
currentPlant:   PlantedFlower | null
```

**Methods:**
- `Plant(flower)` — places a flower in the plot, sets `isOccupied = true`
- `Clear()` — removes the plant, sets `isOccupied = false`
- `DeepCopy()` — snapshot used for rollback

### PlantedFlower
A specific live instance of a plant.

```
id:                GUID (new on each plant action)
flowerTemplateId:  "flower_sunflower" | "flower_rose" | ...
userId:            "user_default"
currentXp:         int  (starts at 0)
currentStage:      int  (starts at 1, server recomputes)
plantedAt:         DateTime UTC
lastWateredAt:     DateTime UTC (min = DateTime.MinValue)
lastFertilizedAt:  DateTime UTC (min = DateTime.MinValue)
```

### FlowerTemplate
Master data for one flower species. Shared across all users.

```
id:               "flower_sunflower"
name:             "Sunflower"
basePrice:        50
imageUrl:         ""
synergyId:        null
harvestProductId: "harvest_sunflower_bloom"
stages:           [ StageDefinition, ... ]
```

### StageDefinition
XP threshold to reach a given stage.

```
level:      int    (1, 4, 7 for sunflower)
xpRequired: int    (0, 100, 300 for sunflower)
modelKey:   string ("stage_seedling", "stage_young", "stage_mature")
```

### CareAction
One care action sent to the server.

```
actionId:    GUID  (idempotency key)
plotId:      "plot_0"
actionType:  "PLANT" | "WATER" | "FERTILIZE" | "PESTICIDE" | "HARVEST"
referenceId: FlowerTemplate.Id (for PLANT) | Item.Id (for consumables)
timestamp:   DateTime UTC
```

---

## FlowerTemplate — XP Logic

### ComputeStageForXp(currentXp)
Finds the highest stage where `xpRequired <= currentXp`.

```
currentXp=0   → Stage 1  (xpRequired=0)
currentXp=50  → Stage 1  (not yet at 100)
currentXp=100 → Stage 4  (xpRequired=100)
currentXp=299 → Stage 4  (not yet at 300)
currentXp=300 → Stage 7  (xpRequired=300) ← MAX
```

### GetXpRequiredForStage(level)
Returns the `xpRequired` for a given stage level. Used to calculate the progress bar boundaries.

### GetNextStageXp(currentStage)
Returns the `xpRequired` for the next stage, or `-1` if already at max.

---

## GardenManager — Operations

### Initialize
```
Start() → InitializeGarden()
    → GetFlowerTemplatesAsync()  ← load template catalog
    → GetGardenStateAsync()      ← load 9 plots
    → OnGardenStateUpdated event ← Presenter refreshes UI
```

### OptimisticPlant(plotId, flowerTemplateId)

```
Preconditions: plot exists, plot.IsOccupied == false, plot.IsPendingSync == false
               inventory has a seed entry for flowerTemplateId

1. plot.IsPendingSync = true
2. plot.Plant(new PlantedFlower(flowerTemplateId, userId))
3. InventoryManager.LocalRemoveItem(seedEntry.Id, 1)
4. OnGardenStateUpdated → UI refresh

[Async] SyncBatchActionsAsync([CareAction(PLANT, flowerTemplateId)])
  Success: plot.IsPendingSync = false, UpdateLocalState(serverResponse)
  Failure: plot.Clear(), plot.IsPendingSync = false
           InventoryManager.LocalAddItem(seedEntry.Id, 1), UI refresh
```

### OptimisticUseConsumable(plotId, actionType, inventoryItemId, referenceId)

```
Preconditions: plot.IsOccupied == true, plot.IsPendingSync == false
               inventory entry exists with quantity > 0

1. plot.IsPendingSync = true
2. InventoryManager.LocalRemoveItem(inventoryItemId, 1)
3. OnGardenStateUpdated → UI refresh

[Async] SyncBatchActionsAsync([CareAction(actionType, referenceId)])
  Success: UpdateLocalState(serverResponse)  ← server recalculates XP + stage
  Failure: plot.IsPendingSync = false
           InventoryManager.LocalAddItem(inventoryItemId, 1), UI refresh
```

### OptimisticHarvest(plotId)

```
Preconditions: plot.IsOccupied == true, plot.IsPendingSync == false
               plant.CurrentStage >= template.MaxStageLevel

1. snapshot = plant.DeepCopy()
2. plot.IsPendingSync = true
3. plot.Clear()
4. InventoryManager.LocalGrantHarvestItem(harvestProductId, 1)
5. OnGardenStateUpdated → UI refresh

[Async] SyncBatchActionsAsync([CareAction(HARVEST, harvestProductId)])
  Success: plot.IsPendingSync = false, UpdateLocalState(serverResponse)
  Failure: plot.Plant(snapshot), plot.IsPendingSync = false
           InventoryManager.LocalRevokeHarvestItem(harvestProductId, 1), UI refresh
```

---

## MockGardenService — Mock Data

### Flower Templates

| ID | Name | Stages (Level → XP) | Harvest Product |
|----|------|---------------------|-----------------|
| `flower_sunflower` | Sunflower | 1→0, 4→100, 7→300 | `harvest_sunflower_bloom` |
| `flower_rose` | Rose | 1→0, 4→120, 7→360 | `harvest_rose_bloom` |

### Initial Plots
- 9 plots: `plot_0` .. `plot_8` in `garden_default`
- `plot_0` pre-planted with `flower_sunflower`, `currentXp = 50`
- All other plots: empty

### Server Delays (mock)
- `GetFlowerTemplatesAsync`: 30ms
- `GetGardenStateAsync`: 50ms
- `SyncBatchActionsAsync`: 50ms

---

## Events

| Event | Signature | Fired When |
|-------|-----------|------------|
| `OnGardenStateUpdated` | `List<Plot>` | After every local predict and after every server sync |
| `OnActionSynced` | `(plotId, actionType)` | After server confirms an action |
