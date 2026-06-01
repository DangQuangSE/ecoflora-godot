# Phase 6: E2E Verification

**Layer:** Cross-cutting (BE + Godot running together)
**Stories:** P1 — all acceptance criteria from spec FR-05 (Task C)

## Requirements
Validate the complete flow end-to-end with a real running BE and Godot client: create session, complete session, confirm DB state, confirm Godot UI, confirm fail path. Fix any bugs discovered.

## Files

| File | Action | Purpose |
|------|--------|---------|
| Any BE or Godot file | Fix-as-needed | Bug fixes discovered during smoke test |

## Steps
1. Start the BE (`dotnet run`) and confirm it boots without errors. Open the `InventoryItems` and `FocusSessions` tables in a DB viewer to observe changes live.
2. In Godot editor, set `FocusManager.use_mock = false` and `FocusManager.bypass_violation_detection = true`. **Temporarily lower `RewardCalculationService` tier floor to 1 min** (change `>= 25` to `>= 1`) so a 5-min test session hits the first tier and grants 2× Watering Can. Run the game, log in, navigate to the focus timer. Set duration to 5 min and complete the session. Confirm: (a) `FocusSessions` DB row created on start, (b) `CompletedAt` set on PATCH, (c) `InventoryItems` shows Watering Can quantity increased by 2. **Revert the tier floor to 25 after this step before committing.**
3. Check Godot's result panel shows the item list, not "+X XP" text. Open the inventory screen (if accessible) and confirm the Watering Can count matches the DB.
4. Run a fail test: start a session, pause the app 3 times to trigger violations. Confirm: (a) `FocusSessions` row shows FAILED status, (b) `InventoryItems` NOT changed, (c) all plots show -20 XP applied in Godot.
5. Run a session shorter than 25 min (use the 5-min slider as proxy, or temporarily lower the no-reward threshold in `RewardCalculationService` to test the empty-reward path). Confirm result panel shows the empty-reward message and no DB inventory changes.
6. If any step fails, fix the root cause in the appropriate layer file, re-run from that step. Document fixed bugs as inline comments or in a brief note in this file's `## Bugs Fixed` section below.

## Success Criteria
- POST `/api/focus-sessions` → DB row with `Status = IN_PROGRESS`
- PATCH `.../complete` → `Status = COMPLETED`, `InventoryItems` Watering Can qty +2 for 25-min session
- PATCH `.../complete` for 50-min session → `InventoryItems` Watering Can +2, Fertilizer +1
- PATCH `.../fail` → `Status = FAILED`, `InventoryItems` unchanged
- Godot result panel: completed session shows item list; failed session shows "-20 XP" text
- Zero Godot script errors in Output panel for both paths

## Risks
- Timer must reach natural end for complete path; use `bypass_violation_detection = true` and a 5-min session to keep test time short
- If `InventoryItems` row does not exist for a user, `GrantItemAsync` creates it — verify the user account was set up via normal login before this test
