# 07 — Gameplay Mechanics

## XP System

### XP per Action

| Action | XP Grant | Source |
|--------|----------|--------|
| Water (`WATER`) | +20 XP | `item_water.receivedExp = 20` |
| Fertilize (`FERTILIZE`) | +50 XP | `item_fertilizer.receivedExp = 50` |
| Pesticide (`PESTICIDE`) | +50 XP | `item_pesticide.receivedExp = 50` |
| Plant (`PLANT`) | 0 XP | — |
| Harvest (`HARVEST`) | 0 XP | — |

### Cooldown per Action

| Action | Cooldown |
|--------|----------|
| Water | 3600 seconds (1 hour) |
| Fertilize | 7200 seconds (2 hours) |
| Pesticide | 7200 seconds (2 hours) |

> Cooldown is per-plant, per-action-type (each plant has its own timer). Not yet enforced in MVP — present in DB schema only.

---

## Stage Progression

### Stage Thresholds

#### Sunflower (`flower_sunflower`)

| Stage Level | XP Required | Model Key | State |
|-------------|------------|-----------|-------|
| 1 | 0 | `stage_seedling` | Seedling |
| 4 | 100 | `stage_young` | Young plant |
| 7 | 300 | `stage_mature` | Mature (Harvestable) |

#### Rose (`flower_rose`)

| Stage Level | XP Required | Model Key | State |
|-------------|------------|-----------|-------|
| 1 | 0 | `stage_seedling` | Seedling |
| 4 | 120 | `stage_young` | Young plant |
| 7 | 360 | `stage_mature` | Mature (Harvestable) |

> **Note:** Stage definitions only have 3 milestones (1, 4, 7). Intermediate levels (2, 3, 5, 6) are not yet defined — the server computes stage as the highest milestone where `xpRequired <= currentXp`.

### How to Compute Stage from XP

```python
def compute_stage(current_xp, stages):
    best_level = stages[0].level
    best_xp    = stages[0].xp_required
    for s in stages:
        if s.xp_required <= current_xp and s.xp_required >= best_xp:
            best_level = s.level
            best_xp    = s.xp_required
    return best_level
```

### Concrete Example (Sunflower)

| CurrentXp | Stage | Progress bar | Notes |
|-----------|-------|-------------|-------|
| 0 | 1 | 0 / 100 | Just planted |
| 50 | 1 | 50 / 100 | Growing |
| 100 | 4 | 0 / 200 | New stage! |
| 200 | 4 | 100 / 200 | |
| 300 | 7 | MAX | Ready to harvest |

---

## Harvest System

### Harvest Conditions
- `plot.IsOccupied == true`
- `plot.IsPendingSync == false`
- `plant.CurrentStage >= template.MaxStageLevel`

### Harvest Yield

| FlowerTemplate | HarvestProductId |
|---------------|------------------|
| `flower_sunflower` | `harvest_sunflower_bloom` |
| `flower_rose` | `harvest_rose_bloom` |

The harvest product is added to Inventory with `category = HarvestProduct`.

---

## PlantExpBarView — XP Bar Display

### World Space Canvas Setup
- Canvas attached as a child of the plant GameObject
- Scale: 0.01 (100 canvas units = 1 world unit)
- Position: `(0, 1.5)` — 1.5 world units above the plant

### Layout (canvas units)

| Element | Size | Position | Font |
|---------|------|----------|------|
| Background | 260 × 26 | (0, 8) | — |
| LevelLabel | 110 × 30 | (−140, 0) | 22 px |
| ProgressGroup | 260 × 50 | (60, 0) | — |
| XpLabel | 260 × 20 | (0, −17) | 14 px |
| FillImage | inside ProgressGroup | — | — |
| MaxBadge | shown when at max | — | — |

### Display Logic

```
currentStage = ComputeStageForXp(currentXp)
maxStage     = template.MaxStageLevel
prevXp       = GetXpRequiredForStage(currentStage)
nextXp       = GetNextStageXp(currentStage)  ← returns -1 if max

atMax = currentStage >= maxStage || nextXp < 0
if atMax:
    progressGroup.hide()
    maxBadge.show()
    fillImage.fillAmount = 1.0
    xpLabel.text = "MAX"
else:
    span = nextXp - prevXp
    into = clamp(currentXp - prevXp, 0, span)
    fillImage.fillAmount = into / span
    xpLabel.text  = "{currentXp} / {nextXp}"
    levelLabel.text = "Lv.{currentStage}"
```

---

## Soil Wetness (PlotView)

The soil color reflects the last watering time:
- **Wet** (dark brown): `DateTime.UtcNow − LastWateredAt < 30 minutes`
- **Dry** (grey): otherwise

---

## Mock Initial State

On game start (MockGardenService):

| Plot | State | Flower | XP |
|------|-------|--------|----|
| plot_0 | Occupied | flower_sunflower | 50 |
| plot_1 .. plot_8 | Empty | — | — |

Initial inventory (MockInventoryService):
- 3× Sunflower Seed
- 2× Rose Seed
- 10× Watering Can
- 5× Fertilizer
- 5× Pesticide
