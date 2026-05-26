# Spec: Garden System — Full Loop (Plant → Grow → Harvest)

**Date:** 2026-05-26
**Status:** Draft

---

## Problem Statement

GardenScene hiện chỉ có player và camera. Game cần core loop của farming: player đặt hạt giống vào ô đất, cây lớn qua các stage, thu hoạch ra sản phẩm — để demo được flow gameplay chính.

---

## User Stories

- **[P1]** As a player, I want to tap an empty plot when I have a seed in my inventory so that I can plant a flower.
  Accepted when: plot changes from empty → planted state, seed count in inventory decreases by 1.

- **[P1]** As a player, I want to see the flower's current growth stage visually on the plot so that I know when it's ready to harvest.
  Accepted when: each stage (1, 4, 7) shows a distinct visual (color or sprite) on the plot node.

- **[P1]** As a player, I want to tap a plot at max stage so that I can harvest and receive a harvest product in my inventory.
  Accepted when: plot clears, harvest product count in InventoryManager increases by 1.

- **[P2]** As a player, I want to see a popup when I approach a plot showing available actions (Plant / Harvest) so that interactions are discoverable.
  Accepted when: popup appears within 80px of plot center, disappears when player moves away.

- **[P2]** As a player, I want to water/fertilize/apply pesticide on a planted flower to gain XP so that I can speed up growth.
  Accepted when: care action adds correct XP (water +20, fertilizer +50, pesticide +50), stage updates if threshold crossed.

- **[P3]** *(out of scope)* Real-time growth timer, backend persistence, plot unlocking.

---

## Functional Requirements

1. **FR-01 — GardenManager autoload:** Manages 8 Plot instances in memory (2×4 layout). Exposes `get_plots()`, `plant(plot_id, flower_template_id)`, `harvest(plot_id)`. Emits `plots_updated` signal.
2. **FR-02 — InventoryManager autoload:** Tracks seed and harvest_product items. Exposes `get_inventory()`, `consume_item(reference_id)`, `add_harvest_product(reference_id)`. Emits `inventory_updated` signal.
3. **FR-03 — MockGardenService:** Returns 2 FlowerTemplates: Sunflower (Lv1=0xp, Lv4=100xp, Lv7=300xp) and Rose (Lv1=0xp, Lv4=120xp, Lv7=360xp). Returns initial 8 Plot states (all empty).
4. **FR-04 — MockInventoryService:** Returns initial inventory: 3× sunflower_seed, 3× rose_seed.
5. **FR-05 — Plot.tscn scene:** Individual plot node. Renders empty / planted (stage 1–7) / ready-to-harvest state. Shows plant button or harvest button via proximity popup.
6. **FR-06 — GardenScene integration:** Spawns 8 Plot nodes at fixed positions. Wires player proximity detection to plot interaction popup.
7. **FR-07 — InteractionManager stub:** Receives plot tap events, routes to GardenManager.plant() or GardenManager.harvest(). No complex event bus required in this phase.
8. **FR-08 — Stage visual:** Each plot shows a colored rect or placeholder sprite keyed to `model_key` in StageDefinition. Distinct visual for empty / stage 1 / stage 4 / stage 7 / harvest-ready.
9. **FR-09 — XP for demo:** On plant, flower starts at XP=0. For MVP demo, a "Add XP" debug button on the plot popup advances XP by 150 (to trigger stage 2→4→7). Real care actions are P2.

---

## Non-Functional Requirements

- **Interaction range:** Popup appears when player center is ≤ 80px from plot center.
- **Signal discipline:** GardenManager → UI via signals only. No direct Manager→Scene calls.
- **Architecture:** GardenManager and InventoryManager must not import each other. Communicate via domain objects only.
- **No persistence:** State is in-memory only. Resets on scene reload.

---

## Success Criteria

- [ ] 8 plots visible in GardenScene at game start
- [ ] Player can plant sunflower seed: plot shows planted state, seed count drops from 3 to 2
- [ ] Debug XP button advances flower through 3 distinct visual stages
- [ ] Player can harvest at max stage: plot clears, harvest_sunflower_bloom count = 1 in InventoryManager
- [ ] Inventory signal fires after every plant/harvest — no stale UI state

---

## Out of Scope

- Real-time growth timer (XP auto-accumulates over seconds)
- Backend API calls or persistence across sessions
- Plot unlocking / purchasing
- Care actions cooldown UI (P2)
- InteractionManager as full event bus (stubbed only)

---

## Assumptions

- GardenScene TileMap is already placed and sized — plots are overlaid as Node2D children, not TileMap cells.
- Player.tscn already has a position signal or the scene can read `$Player.global_position` each frame.
- Placeholder colored rects are acceptable for plant visuals — no art assets required.
- `project.godot` already declares GardenManager and InventoryManager autoload entries (they need `.gd` files created).
