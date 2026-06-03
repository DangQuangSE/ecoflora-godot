# Brainstorm: Currency, Vitality Bar & Shop System

**Date:** 2026-06-03

---

## Ideas Explored

**A. User XP persistence fix** — `CurrentXp` hardcoded to 0 in BE mapper (`MappingProfile.cs:20`). Add field to `User` entity, remove hardcode. Straightforward DB migration.

**B. Currency display** — `currency` field already exists on BE (`User.Currency`) and synced to Godot on login, but zero UI widget shows it. Simple HUD addition.

**C. Vitality bar (sức sống / ❤️)** — 6-hour timer, real-time (offline timer via stored timestamp). Claim gives random reward from pool: EXP, items, or currency. Full BE sync.

**D. Shop system** — Sells consumables, seeds, decorations. Currency = premium (top-up via admin) + free (daily tasks / vitality). No shop entity exists in BE yet.

**E. Daily tasks as free currency source** — Not scoped in this session; referenced as a future earn mechanism by user. Vitality bar claim is the only defined free source for now.

**F. Harvest earning currency** — Currently the harvest endpoint returns `newCurrencyTotal`, implying harvest earns currency. Needs clarification: keep, remove, or reduce after premium model is added.

---

## User's Direction

- Full BE sync for all systems (no local-only)
- User XP: add `CurrentXP` field to `User` entity (full progression)
- Vitality bar reward: **random** from pool (EXP + items + currency)
- Shop scope: consumables + seeds + decorations (full shop)
- Currency model: **premium** — top-up via separate website, admin sets currency manually (e.g., 10k VND = +10 currency); free earn via daily tasks (vitality claim included)

---

## Open Questions

1. **Harvest currency earn** — Should harvest still grant currency, or is that replaced by premium model? Currently hardcoded in BE.
2. **Level formula** — How many XP per level threshold? (e.g., L2=500, L3=1500, L4=3000?) Needs defining before BE migration.
3. **Vitality reward pool values** — Exact amounts: how much EXP per claim? How many items? How much currency? What are the probabilities for each reward type?
4. **Decoration system** — What are decorations? Are they placed on the garden (new Node type) or purely cosmetic (background/UI)? Biggest unknown in the shop scope.
5. **Daily tasks** — Are daily tasks part of this feature set or a separate future feature? Does vitality bar count as a daily task?

---

## Risks

1. **Decoration system scope creep** — Deco requires a new entity in BE, new scene in Godot, and placement logic. This alone is a large feature; may need its own brainstorm.
2. **Admin grant flow** — If currency is premium only, shop purchases must be validated carefully against real balance. Accidental negative balance or double-spend must be prevented at BE layer.
3. **DB migration risk** — Adding `CurrentXP` to `User` entity requires EF Core migration. Existing users default to 0, which is fine, but level-up recalculation from plant XP history is not straightforward (plant XP ≠ user XP).
