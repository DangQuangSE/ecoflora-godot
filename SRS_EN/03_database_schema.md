# 03 — Database Schema

> Backend schema (PostgreSQL / MySQL). The client (Unity/Godot) mirrors these entities as in-memory objects.

---

## ERD Overview

```
User ──────────────── UserGarden ──── UserInventory
  │                        │                │
  │                    UserGarden        InventoryItem ─── FlowerTemplate
  │                        │               ├── item_id ──── Item
  │                        │               └── decor_id ─── Decor
  │                      Plot ──── PlantedFlower ─── FlowerTemplate
  │                                                        │
  │                                                     Synergy
  │
  ├── FocusSession
  └── RefreshToken

API (standalone, no FK)
```

---

## 1. User

Stores login information, player profile, and access control.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | Primary key |
| `email` | String | Unique |
| `username` | String | Display name |
| `password_hash` | String | Bcrypt hash |
| `first_name` | String | |
| `last_name` | String | |
| `role` | Enum | `PLAYER`, `ADMIN`, `SUPER_ADMIN` |
| `currency` | Int | In-game currency |
| `level` | Int | Player level |
| `isBanned` | Boolean | Ban status |

---

## 2. FlowerTemplate

Master data for each flower species. Immutable during gameplay.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | e.g. `flower_sunflower` |
| `name` | String | e.g. `"Sunflower"` |
| `base_price` | Int | Sell price |
| `image_url` | String | Thumbnail |
| `synergy_id` | GUID (FK, nullable) | → Synergy |
| `harvest_product_id` | String | Item ID yielded at harvest |

> **Client-side only** (not stored in DB): `stages[]` — array of `StageDefinition { level, xp_required, model_key }`.
> In Unity, stored in `ItemDataSO` / `FlowerTemplate` class, not synced to server.

---

## 3. PlantedFlower

A specific instance of a plant currently growing in a garden.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | New UUID on every plant action |
| `flower_template_id` | GUID (FK) | → FlowerTemplate |
| `user_id` | GUID | Owner |
| `current_xp` | Int | Accumulated XP |
| `current_stage` | Int | Current stage (server recomputes from XP) |
| `last_watered_at` | DateTime | UTC |
| `last_fertilized_at` | DateTime | UTC |
| `planted_at` | DateTime | UTC |

---

## 4. Item

Consumable items: watering can, fertilizer, pesticide.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | e.g. `item_water` |
| `name` | String | e.g. `"Watering Can"` |
| `price` | Int | Shop price |
| `image_url` | String | |
| `cooldown_time` | Int | Seconds (water=3600, fert/pest=7200) |
| `type` | Enum | `WATER`, `FERTILIZER`, `PESTICIDE` |
| `received_exp` | Int | XP granted to plant (water=20, fert/pest=50) |

---

## 5. Decor

Decorative items for the garden.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | |
| `name` | String | |
| `price` | Int | |
| `image_url` | String | |

---

## 6. Synergy

Buff effects when compatible flower species are placed next to each other.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | |
| `name` | String | Effect name |
| `xp_plus` | Int | Bonus XP per care action |
| `cooldown_minus` | Int | Cooldown reduction (seconds) |

---

## 7. UserGarden

A garden belonging to a user.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | e.g. `garden_default` |
| `user_id` | GUID (FK) | → User |
| `garden_name` | String | Garden name |

---

## 8. UserInventory

Each user has exactly one inventory.

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | |
| `user_id` | GUID (FK, Unique) | → User |
| `current_slots` | Int | Number of occupied slots |

---

## 9. InventoryItem

One entry in the inventory. Polymorphic — wraps one of three item types (only one FK is non-null).

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | Per-user entry ID |
| `inventory_id` | GUID (FK) | → UserInventory |
| `flower_template_id` | GUID (FK, nullable) | Non-null if this is a seed |
| `item_id` | GUID (FK, nullable) | Non-null if this is a consumable |
| `decor_id` | GUID (FK, nullable) | Non-null if this is a decor item |
| `quantity` | Int | Stack size |
| `category` | Enum | `Seed`, `Consumable`, `Decor`, `HarvestProduct` |

> **GetReferenceId()** — client helper: returns `flower_template_id ?? item_id ?? decor_id`.

---

## 10. Plot

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | e.g. `plot_0` .. `plot_8` |
| `garden_id` | GUID (FK) | → UserGarden |
| `plot_index` | Int | Position in 3×3 grid (0–8) |
| `planted_flower_id` | GUID (FK, nullable) | → PlantedFlower; null if empty |

---

## 11. FocusSession

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | |
| `user_id` | GUID (FK) | → User |
| `start_time` | DateTime | UTC |
| `target_duration` | Int | Minutes |
| `strikes` | Int | Number of violations (app-switching) |
| `status` | Enum | `IN_PROGRESS`, `COMPLETED`, `FAILED` |

---

## 12. RefreshToken

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | |
| `user_id` | GUID (FK) | → User |
| `hashed_token` | String | |
| `expires_at` | DateTime | |

---

## 13. API (External API config)

| Column | Type | Notes |
|--------|------|-------|
| `id` | GUID (PK) | |
| `name` | String | e.g. `"OpenWeatherMap"` |
| `base_url` | String | |
| `api_key` | String | |
| `refresh_interval` | Int | Minutes |
| `last_synced_at` | DateTime | |

---

## Design Notes

- `InventoryItem` uses nullable FKs instead of separate tables per type — flexible, but requires a `CHECK` constraint to ensure exactly one FK is non-null.
- `PlantedFlower.current_stage` is a **computed field** — the server recomputes it from `current_xp` after each care action. Clients must not trust a client-sent stage value.
- Stage definitions (XP thresholds) are **client-side balancing data** and are not stored in the DB. The backend serves them via a metadata endpoint or config file.
