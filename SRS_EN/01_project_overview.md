# 01 — Project Overview

## Description

**Flow & Flora** is a mobile game that combines virtual garden management, a study focus timer (Focus Mode), and Vietnamese cultural elements. The system consists of:

- **Web Admin Panel**: Manages users, configures items, monitors game state
- **Mobile Game**: Unity (or Godot) — calls REST API to fetch user data, renders the garden, handles gameplay

---

## Core Gameplay Loop

```
[Login]
    ↓
[Enter Garden] → [Select item from Inventory (Bag)]
    ↓
[Plant flower] → [Daily care] → [Harvest]
    ↓               ↓                ↓
  Water          Fertilize/       Receive harvest
  (+20 XP)       Pesticide        product in Inventory
                 (+50 XP each)
    ↓
[Plant levels up] → Lv1 → Lv4 → Lv7 (max)
    ↓
[Focus Mode] → Set timer → Complete → Receive items
```

---

## Flower Lifecycle

| Stage | Level | Description |
|-------|-------|-------------|
| Seedling | Lv 1 | Just planted, XP = 0 |
| Young plant | Lv 2–3 | Growing |
| Grown plant | Lv 4–6 | Developed, XP ≥ Lv4 threshold |
| Mature | Lv 7 | Ready to harvest |

The stage is computed from the current XP using each species' `StageDefinition` table.

---

## Care Actions

| Action | Action Type | XP | Cooldown |
|--------|-------------|-----|----------|
| Plant | `PLANT` | — | — |
| Water | `WATER` | +20 XP | 1 hour (3600s) |
| Fertilize | `FERTILIZE` | +50 XP | 2 hours (7200s) |
| Spray pesticide | `PESTICIDE` | +50 XP | 2 hours (7200s) |
| Harvest | `HARVEST` | — | — |

---

## Feature List

### 1. Garden Management
- Each user can own multiple gardens (`UserGarden`)
- Each garden has 9 plots (`Plot`) in a 3×3 grid
- Swipe gesture to plant/water multiple plots at once

### 2. Item Economy
- **Seeds (Seed)**: Planted into empty plots
- **Consumables**: Watering Can, Fertilizer, Pesticide
- **Harvest Products**: Items received after harvesting
- **Decor**: Garden decorations (not in MVP)

### 3. Focus Mode (Study Concentration)
- Set a focus/study timer
- App tracks background state, detects violations (switching apps)
- On completion → receive items as rewards
- On failure → plants in garden lose XP

### 4. Quests
- **Daily quests**: Daily check-in, water 3 times/day, etc.
- **System quests**: Own a specific flower species, reach a certain level, etc.

### 5. Synergy
- Place "compatible" flower species next to each other → buffs (reduced cooldown, bonus XP)

### 6. Weather API
- Sync real-world weather → affects the garden (wilting in heat, flooding in rain)

### 7. GPS Check-in
- Travel to the real-world garden location → check in → receive exclusive seeds

### 8. Vietnamese Cultural Elements
- Traditional decorations (thatched houses, ceramic ware)
- Flowers from Vietnamese folklore

### 9. Design & Voting
- Build a farm and join voting contests
- Top-ranking gardens earn a place on the Tan Ba Flower Garden leaderboard

---

## User Roles

| Role | Permissions |
|------|-------------|
| `PLAYER` | Play the game, manage their own garden |
| `ADMIN` | Manage items, configure game rules |
| `SUPER_ADMIN` | Full access including user banning |
