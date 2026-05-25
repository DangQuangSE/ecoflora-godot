# 05 — Inventory System

## Overview

The Inventory System manages the player's bag: seeds, consumables, decorations, and harvest products.

---

## Entities

### UserInventory
Container for all items belonging to one user.

```
id:            GUID
userId:        "user_default"
currentSlots:  int
items:         List<InventoryItem>
```

### InventoryItem
One entry in the inventory. Polymorphic — wraps one of three item types.

```
id:               GUID  (per-user entry, unique)
inventoryId:      GUID  → UserInventory
flowerTemplateId: GUID | null  ← non-null if Seed
itemId:           GUID | null  ← non-null if Consumable
decorId:          GUID | null  ← non-null if Decor
harvestProductId: string | null ← non-null if HarvestProduct
quantity:         int
category:         ItemCategory enum
```

**GetReferenceId()** — returns the actual item ID:
```
if category == Seed           → return flowerTemplateId
if category == Consumable     → return itemId
if category == Decor          → return decorId
if category == HarvestProduct → return harvestProductId
```

### ItemCategory (Enum)
```
Seed           = 0  ← Flower seed
Consumable     = 1  ← Water / Fertilizer / Pesticide
Decor          = 2  ← Decorative item
HarvestProduct = 3  ← Item received on harvest
```

### Item (domain entity — mirrors DB)
```
id:           "item_water" | "item_fertilizer" | "item_pesticide"
name:         string
type:         ItemType enum  (Water, Fertilizer, Pesticide)
receivedExp:  int    ← XP granted to plant when used
cooldownTime: int    ← seconds
price:        int
imageUrl:     string
```

### ItemType (Enum)
```
Water      → CareActionType.Water
Fertilizer → CareActionType.Fertilize
Pesticide  → CareActionType.Pesticide
```

---

## ItemDataSO (Unity ScriptableObject)

> In Godot, this would be a `Resource` class.

Each catalog item is stored in one `ItemDataSO`:

```
id:              string       ← matches DB Item.id or FlowerTemplate.id
displayName:     string
icon:            Sprite / Texture
plantPrefab:     GameObject   ← prefab for Seeds (null otherwise)
category:        ItemCategory
consumableType:  ItemType     ← only for Consumables
receivedExp:     int          ← only for Consumables
isConsumable:    bool
```

**isConsumable** = `category == Consumable`.

---

## InventoryManager — Operations

### RefreshInventory()
```
→ MockInventoryService.GetInventoryAsync(userId)
→ _currentInventory = result
→ OnInventoryUpdated event
```

### UseItem(inventoryItemId, quantity=1)
Standard (non-optimistic) path — waits for server confirmation before updating UI:
```
1. entry = FindEntry(inventoryItemId)
2. UseItemUseCase.ExecuteAsync(userId, inventoryItemId, referenceId, quantity)
3. On success: RefreshInventory()
4. OnItemUsed event
```

### LocalRemoveItem(inventoryItemId, quantity=1)
Optimistic deduction:
```
entry.Quantity -= quantity
clamp to 0
OnInventoryUpdated event
OnItemUsed event
```

### LocalAddItem(inventoryItemId, quantity=1)
Rollback helper:
```
entry.Quantity += quantity
OnInventoryUpdated event
```

### LocalGrantHarvestItem(harvestProductId, quantity=1)
Harvest yield — creates a new entry if one does not yet exist:
```
existing = Items.Find(category==HarvestProduct && referenceId==harvestProductId)
if existing: existing.Quantity += quantity
else:        Items.Add(new InventoryItem for HarvestProduct)
OnInventoryUpdated event
```

### LocalRevokeHarvestItem(harvestProductId, quantity=1)
Rollback harvest:
```
entry.Quantity -= quantity
if Quantity <= 0: Items.Remove(entry)
OnInventoryUpdated event
```

---

## Mock Inventory Data

| InventoryItemId | Category | ReferenceId | Quantity |
|-----------------|----------|-------------|---------|
| `inv_seed_sunflower` | Seed | `flower_sunflower` | 3 |
| `inv_seed_rose` | Seed | `flower_rose` | 2 |
| `inv_water` | Consumable | `item_water` | 10 |
| `inv_fertilizer` | Consumable | `item_fertilizer` | 5 |
| `inv_pesticide` | Consumable | `item_pesticide` | 5 |

---

## Item Catalog (MainCatalog)

| Item ID | Display Name | Category | XP | Cooldown |
|---------|-------------|----------|----|----------|
| `flower_sunflower` | Sunflower Seed | Seed | — | — |
| `flower_rose` | Rose Seed | Seed | — | — |
| `item_water` | Watering Can | Consumable | 20 | 3600s |
| `item_fertilizer` | Fertilizer | Consumable | 50 | 7200s |
| `item_pesticide` | Pesticide | Consumable | 50 | 7200s |

---

## Events

| Event | Signature | Fired When |
|-------|-----------|------------|
| `OnInventoryUpdated` | `UserInventory` | After every local add/remove/grant/revoke |
| `OnItemUsed` | `(referenceId, remainingQuantity)` | After LocalRemove or UseItem confirmation |
