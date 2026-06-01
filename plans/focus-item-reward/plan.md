# Plan: Focus Session Item Reward
Status: ðŸŸ¡ In Progress
Date: 2026-05-31
Mode: Hard

## Overview
Replace the abstract XP reward from focus sessions with concrete inventory items (Watering Can, Fertilizer, Pesticide) scaled by session duration, completing the learn â†’ earn â†’ care loop in time for the EXE2 demo.

## Phases
- [x] Phase 1: BE Reward Logic â€” Add `RewardCalculationService` and `RewardItemDto`; wire into `CompleteAsync`
- [x] Phase 2: BE Response Contract â€” Extend `FocusSessionDto` with `RewardItems`; register DI; verify PATCH response
- [x] Phase 3: Godot Service Layer — Change `FocusService._patch_terminal()` to return the full response `Dictionary`
- [x] Phase 4: Godot Autoloads — Wire reward signal through `FocusManager`; update `GardenManager` and `InventoryManager`
- [x] Phase 5: Godot Scene — Replace `ResultLabel` with item-list panel in `FocusTimerUI`
- [ ] Phase 6: E2E Verification â€” Full flow smoke test; fix any bugs discovered

## Research Summary
BE uses AutoMapper to map `FocusSession` â†’ `FocusSessionDto`. `RewardItems` cannot be AutoMapper-mapped because it requires a separate service call; it must be populated manually after the base mapping. `InventoryService.GrantItemAsync()` already handles upsert and commits per item call â€” no new grant logic needed. The `GrantItemRequest` takes `TargetUserId + ItemId + Quantity`; the user GUID comes from the JWT claim already used in `FocusSessionService`.

Godot's `FocusService._patch_terminal()` currently returns `bool` (discards body after reading `isSuccess`). Changing it to return a `Dictionary` (the unwrapped `data` field) lets `FocusManager` read `rewardItems` without a second HTTP call. Fail path keeps the existing `-20 XP` bulk apply via `apply_focus_xp_bulk(-20)` in `GardenManager`; success path removes `apply_focus_xp_bulk(minutes)`.

Chosen approach: single new service class on BE, minimal Godot signal chain (`session_reward_received`), no new HTTP endpoint, no DB migration.

## Dependencies
- Watering Can UUID in DB: `3c9606a3-f3ed-4491-9793-45f1dcd81511`
- Fertilizer UUID in DB: `37ea3e52-1cbc-45b1-856f-dabd569b61f7`
- Pesticide UUID: unknown at plan time â€” must query DB before Phase 1 or skip Pesticide tier for demo
- `InventoryService.GrantItemAsync()` must remain public (it is â€” no change needed)

## Risks
- HIGH: Pesticide UUID unknown â€” hardcode a placeholder and skip â‰¥100 min tier, or query `Items` table before coding
- MEDIUM: `GrantItemAsync` commits once per item; if second grant fails, first item is already persisted (partial reward) â€” acceptable for demo, log a warning
- LOW: Old BE format (no `rewardItems` field) â€” Godot must use `.get("rewardItems", [])` fallback; already in research spec
- LOW: CONNECT_ONE_SHOT on `session_completed` in FocusTimerUI means reward signal must be connected without ONE_SHOT so it persists â€” verify connection strategy in Phase 5
- LOW (NOTED): `InventoryManager.add_reward_item()` updates in-memory only; items are already granted on BE. If a post-session inventory refresh overwrites local list before UI reads it, the optimistic add will flicker. Verify no autoload triggers a full inventory refresh after `session_completed` â€” if one does, remove the optimistic add and rely solely on the refresh.
