# 06 — Interaction Flows

## InteractionMode (Enum)

At any given time, only one mode is active:

```
None            ← default, no tool equipped
Planting        ← holding a seed; click an empty plot to plant
UsingConsumable ← holding water/fertilizer/pesticide; click an occupied plot
Harvesting      ← harvest mode active; click a max-stage plot to harvest
```

---

## Flow 1: Planting

```
[User opens Bag UI]
        ↓
[Clicks a Seed item in Inventory]
        ↓
[InventoryView] → InteractionManager.SelectSeedToPlant(flowerTemplateId)
        ↓
 InteractionManager.CurrentMode = Planting
 InteractionManager.ActiveSeedId = flowerTemplateId
 HUD icon → seed icon
        ↓
[User swipes / clicks an empty Plot]
        ↓
[SwipeInteractionHandler or PlotView.OnPointerClick]
    checks: mode == Planting && plot.IsOccupied == false
        ↓
[GardenManager.OptimisticPlant(plotId, flowerTemplateId)]
        ↓
 [Local predict] plot.Plant(new PlantedFlower)
 inventory seed -1
 UI refresh immediately
        ↓
 [Async] MockGardenService.SyncBatchActionsAsync
    Success → UpdateLocalState(serverResponse)
    Failure → plot.Clear(), inventory seed +1, UI refresh
```

---

## Flow 2: Watering / Fertilizing / Spraying (UsingConsumable)

```
[User opens Bag UI]
        ↓
[Clicks a Consumable item (Water / Fertilizer / Pesticide)]
        ↓
[InventoryView] → InteractionManager.SelectConsumableToUse(entry, data)
        ↓
 InteractionManager.CurrentMode = UsingConsumable
 InteractionManager.ActiveConsumableInventoryItemId = entry.Id
 InteractionManager.ActiveConsumableReferenceId = data.Id  ← "item_water" etc.
 InteractionManager.ActiveCareActionType = "WATER" | "FERTILIZE" | "PESTICIDE"
 HUD icon → consumable icon
        ↓
[User swipes / clicks an occupied Plot]
        ↓
[SwipeInteractionHandler or PlotView.OnPointerClick]
    checks: mode == UsingConsumable && plot.IsOccupied == true
        ↓
[GardenManager.OptimisticUseConsumable(
    plotId,
    ActiveCareActionType,
    ActiveConsumableInventoryItemId,
    ActiveConsumableReferenceId
)]
        ↓
 [Local predict] consumable -1
 UI refresh immediately
        ↓
 [Async] MockGardenService.SyncBatchActionsAsync
    Success → plant.CurrentXp += receivedExp, stage recomputed by server
              UpdateLocalState(serverResponse)
    Failure → consumable +1, UI refresh
```

---

## Flow 3: Harvesting

```
[User clicks HarvestToolButton]
        ↓
[HarvestToolButton] → InteractionManager.SelectHarvestMode()
        ↓
 InteractionManager.CurrentMode = Harvesting
 HUD icon → default icon
        ↓
[User swipes / clicks an occupied Plot with a MAX-stage plant]
        ↓
[PlotController.OnPointerClick or SwipeInteractionHandler]
    checks: mode == Harvesting && plot.IsOccupied == true
            plant.CurrentStage >= template.MaxStageLevel
        ↓
[GardenManager.OptimisticHarvest(plotId)]
        ↓
 [Local predict] snapshot = plant.DeepCopy()
 plot.Clear()
 inventory harvest product +1  (create entry if it does not exist)
 UI refresh immediately
        ↓
 [Async] MockGardenService.SyncBatchActionsAsync
    Success → UpdateLocalState(serverResponse)
    Failure → plot.Plant(snapshot)
              inventory harvest product -1
              UI refresh
```

---

## Flow 4: Reset Mode

Call `InteractionManager.ResetMode()` when:
- User taps Cancel / Back
- A plot click is invalid (optional behavior)
- After an action completes (optional — mode may stay active to chain actions)

---

## Swipe Interaction (SwipeInteractionHandler)

Receives touch input and determines which plots are swiped over:
1. `OnPointerDown` — records start point
2. Detect touch movement → Raycast to find `PlotView` underneath
3. For each new plot in the path: apply action according to `CurrentMode`
4. `OnPointerUp` — end swipe

---

## InteractionManager State

```
CurrentMode:                     Planting | UsingConsumable | Harvesting | None
ActiveSeedId:                    "flower_sunflower"  (Planting only)
ActiveConsumableInventoryItemId: "inv_water"         (UsingConsumable only)
ActiveConsumableReferenceId:     "item_water"        (UsingConsumable only)
ActiveCareActionType:            "WATER"             (UsingConsumable only)
```

When switching mode, the old state is cleared:
- `SelectSeedToPlant` → clears consumable state
- `SelectConsumableToUse` → clears seed state
- `SelectHarvestMode` → clears both seed and consumable state
- `ResetMode` → clears everything
