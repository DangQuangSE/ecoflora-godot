# Brainstorm: Garden System — Full Loop

**Date:** 2026-05-26

## Ideas Explored

- **Bottom-up (Manager first)** — Build GardenManager + MockService first, test logic headlessly, add UI later. Solid but slow to see results.
- **Top-down (UI first)** — Build Plot.tscn with hardcoded data, refactor managers later. Fast demo but messy coupling.
- **Parallel (Mock + UI together)** *(chosen)* — MockGardenService + GardenManager + Plot.tscn built in the same phase. Correct architecture, visible results early.

## User's Direction

Start with Plot system as foundation. Full loop: plant → grow → harvest. 8 plots (2×4) in GardenScene. Inventory required (must have seed in bag to plant). Option C chosen: Mock + UI parallel.

## Open Questions

- What triggers XP gain? (For MVP: auto-gain over time OR manual care actions?) → Decided: auto-gain is out of scope; XP added via mock on harvest for now — care actions are P2.
- Growth time per stage: real-time seconds or game-ticks? → For MVP: instant stage preview using mock XP values, no real timer.
- Plot visual: placeholder colored rect or actual sprite? → Placeholder acceptable for demo.

## Risks

1. **InteractionManager scope creep** — CLAUDE.md requires it but building a full event-router adds complexity. Risk: over-engineering for a 1-scene feature. Mitigation: stub it as a pass-through in this phase.
2. **GardenScene layout** — 8 plots need physical placement in TileMap. Risk: manual positioning is brittle. Mitigation: define plot positions as constants in GardenManager, render dynamically.
3. **Inventory coupling** — InventoryManager + GardenManager must stay decoupled (domain signals only). Risk: direct manager calls create upward imports. Mitigation: GardenManager emits signals, InventoryManager listens.
