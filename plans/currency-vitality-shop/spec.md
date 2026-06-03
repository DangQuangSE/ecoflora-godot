# Spec: Currency, Vitality Bar & Shop System

**Date:** 2026-06-03
**Status:** Draft

---

## Problem Statement

Player progression state (XP, currency) resets to 0 on every login because the BE never persists `CurrentXP` and the HUD never displays currency. Players have no passive reward loop (vitality) and no way to spend currency (no shop). This spec covers 4 linked systems: XP persistence fix, currency HUD, vitality bar, and shop.

---

## User Stories

- **[P1]** As a player, I want my XP and level to persist across sessions so that progression feels meaningful.
  Accepted when: login → profile endpoint returns non-zero `CurrentXP` after earning XP in a previous session.

- **[P1]** As a player, I want to see my currency balance in the HUD at all times so that I know when I can afford shop items.
  Accepted when: coin icon + balance visible on main HUD, updates immediately after any currency change.

- **[P1]** As a player, I want a vitality bar (❤️) that fills over 6 hours so that I have a reason to return daily.
  Accepted when: bar shows real-time fill progress; claim button active when full; random reward delivered and confirmed via toast.

- **[P1]** As a player, I want to buy consumables (water, fertilizer, pesticide) from the shop using currency so that I don't run out of care items.
  Accepted when: tap item → shows price → confirm → currency deducted → inventory updated.

- **[P2]** As a player, I want to buy flower seeds from the shop so that I can plant new flower types.
  Accepted when: seed appears in inventory after purchase; can be planted normally.

- **[P2]** As a player, I want to buy decorations for my garden so that I can personalize my space.
  Accepted when: decoration purchased → appears as placeable item in garden.

- **[P3]** _(out of scope — daily tasks system for free currency earn beyond vitality claim)_

---

## Functional Requirements

### System 1 — User XP Persistence (BE + Godot)

1. **FR-01:** Add `CurrentXP` (int, default 0) to `User` entity in eco-backend via EF Core migration.
2. **FR-02:** Remove hardcoded `opt.MapFrom(src => 0)` in `MappingProfile.cs`; map `CurrentXp` from `User.CurrentXP`.
3. **FR-03:** Define level thresholds constant in `UserService`: L2=500, L3=1500, L4=3000, L5=5000, L6=8000, L7=12000.
4. **FR-04:** `GardenService.CareForPlant()` and `GardenService.Harvest()` must also increment `User.CurrentXP` and trigger level-up check. Return `newUserXP` and `newUserLevel` in response.
5. **FR-05:** Godot `UserManager` parses `newUserXP`/`newUserLevel` from garden response and calls `add_harvest_xp()` equivalent.

### System 2 — Currency HUD Display

6. **FR-06:** Add coin icon + label node to HUD (top bar area, near level display).
7. **FR-07:** `UserManager` emits `currency_changed(new_amount: int)` signal; HUD subscribes and updates label.
8. **FR-08:** `update_currency()` in `UserManager.gd` already exists — wire it to the new signal.

### System 3 — Vitality Bar (Sức Sống)

9. **FR-09:** Add `VitalityLastClaim` (DateTime?, nullable) to `User` entity via migration. Null = never claimed.
10. **FR-10:** `GET /api/vitality/status` — returns `{ isReady: bool, secondsUntilReady: int, lastClaim: string? }`. Player-authenticated.
11. **FR-11:** `POST /api/vitality/claim` — validates 6h cooldown, picks random reward, applies it atomically, returns `{ rewardType: string, rewardAmount: int, rewardItemId?: string }`.
12. **FR-12:** Random reward pool (tune after play-test, defaults below):
    - Type A (40%): +200 User XP
    - Type B (40%): 2× water OR 1× fertilizer (random 50/50 between sub-types)
    - Type C (20%): +5 currency
13. **FR-13:** Godot: `VitalityManager` autoload (or component in HUD) polls vitality status on login and every 60s. Emits `vitality_ready` signal.
14. **FR-14:** Godot: Vitality bar UI — heart icon, fill progress bar, countdown label, claim button (enabled when `isReady = true`).
15. **FR-15:** On successful claim: show reward toast (animated), update relevant HUD elements (XP bar, currency, inventory count).

### System 4 — Shop

16. **FR-16:** Add `ShopItem` entity: `{ Id, Name, Description, Price (int), Category (enum: Consumable/Seed/Decoration), ItemTemplateId?, IsActive }`.
17. **FR-17:** `GET /api/shop/items` — returns list of active shop items, filterable by category. Public or player-authenticated.
18. **FR-18:** `POST /api/shop/purchase` — body: `{ shopItemId, quantity }`. Validates: user currency >= price × quantity. Atomically deducts currency, adds to inventory. Returns `{ success, newCurrencyTotal, item, quantity }`.
19. **FR-19:** Admin endpoint to manage shop items (add/edit/toggle active). Can reuse admin pattern from existing admin controller.
20. **FR-20:** Godot: Shop scene (`ShopScene.tscn`) — grid of item cards (icon, name, price), category tabs (Consumables / Seeds / Deco), purchase confirmation dialog.
21. **FR-21:** Deco items in shop are listed but "coming soon" if garden placement system not implemented. [NEEDS CLARIFICATION: deco placement scope]

---

## Non-Functional Requirements

- Performance: Shop item list response < 300ms (small dataset, cacheable).
- Security: `POST /api/shop/purchase` must be atomic (DB transaction) — no double-spend on concurrent requests. Currency can never go negative.
- Security: `POST /api/vitality/claim` must enforce 6h cooldown server-side, never trust client timestamp.
- Availability: Vitality timer must use server-stored `VitalityLastClaim` timestamp, not client clock.

---

## Success Criteria

- [ ] User XP: login after earning XP → `CurrentXP` in profile response matches last session's value (not 0)
- [ ] Currency HUD: coin balance visible and updates within 1 frame of any currency change event
- [ ] Vitality bar: 6h cooldown enforced server-side; claiming twice in < 6h returns 400 error
- [ ] Vitality bar: random reward delivered and reflected in correct system (XP bar / inventory count / currency label) within 2s of claim
- [ ] Shop purchase: currency deducted + inventory item added atomically; no state where one happens without the other
- [ ] Shop: player with 0 currency cannot purchase any item (client validates, server enforces)

---

## Out of Scope

- Daily tasks system (defined as separate future feature)
- Decoration garden placement system (shop lists deco, placement is separate scope)
- Top-up website / payment integration (admin manually grants currency via existing `PUT /api/user/{userId}`)
- Push notifications for vitality ready
- Social/gifting features

---

## Assumptions

- Level thresholds are fixed constants (not dynamically configurable per admin).
- Vitality reward amounts are fixed at deploy time (not A/B testable).
- Shop item catalog is managed by admin via backend; no in-game editor.
- `User.Currency` can only be set by admin (top-up), decremented by shop purchase, or incremented by vitality claim (Type C reward). Harvest does NOT earn currency — remove `user.Currency += template.BasePrice` from `GardenService.Harvest()` (currently line ~232).
- Decoration placement system is out of scope for this spec; deco items exist in shop data only.

---

## [NEEDS CLARIFICATION]

- [ ] **Decoration placement scope**: Are decorations placed as Nodes in the garden (new system) or listed in shop but not yet placeable? Confirm before implementing FR-21 shop deco tab.
