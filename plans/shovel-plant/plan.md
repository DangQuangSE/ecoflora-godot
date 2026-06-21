# Plan: Shovel / Dig Up Plant (xúc cây khỏi ô đất)

Status: 🟢 Code complete — pending manual QA (user-owned, outside this pipeline)
Date: 2026-06-21
Mode: Hard

## Overview

This plan delivers the complete "shovel" feature enabling players to remove planted flowers at any stage and reclaim the seed. Spans both eco-backend (.NET API) and Godot 4 client (GDScript), with new mode toggle, confirmation dialog, optimistic UI + rollback, and BE endpoint following existing harvest pattern precisely.

**Key constraint:** Shovel mode must remain active after each dig-up to allow consecutive plots; only toggling the button again (or selecting another mode) deactivates it.

## Phases

- [x] Phase 1: Backend dig-up endpoint and service — Create `POST /api/garden/plots/{plotId}/dig-up` controller action + service method + inventory seed restoration
- [x] Phase 2: Godot interaction mode refactor — Replace separate `harvest_mode` bool with `enum CurrentMode { NONE, HARVEST, DIG_UP }` in InteractionManager
- [x] Phase 3: GardenManager dig_up function + InventoryManager seed restoration — Optimistic UI pattern with snapshot/rollback + new `restore_seed()` function
- [x] Phase 4: HUD wiring + Plot tap handler + confirm dialog — Connect ShovelButton to toggle_dig_up_mode, add dig-up tap logic with confirmation popup
- [~] Phase 5: Manual end-to-end verification — Deferred: user will run the 15-test checklist in `phase-05-manual-verification.md` themselves outside this pipeline (no Godot CLI available in this environment to execute it)

## Research Summary

### Approach Chosen (from researcher report)

1. **Separate new endpoint** — NOT a reuse of harvest. Route: `POST /api/garden/plots/{plotId}/dig-up`. Mirrors harvest controller/service/transaction/response-envelope exactly.

2. **Single mode enum** — Replace `_harvest_mode: bool` with `_current_mode: enum CurrentMode { NONE, HARVEST, DIG_UP }`. Mutually exclusive modes; toggling one auto-deactivates others.

3. **Confirm dialog in Plot.gd** — Scene layer (not Manager layer) triggers `BaseDialog.show_confirm()` on plot tap when dig_up_mode is active. Awaits `confirmed` signal before calling `GardenManager.dig_up()`. Keeps Managers free of UI concerns.

4. **Optimistic dig_up()** — Matches harvest pattern:
   - Check occupied + not pending_sync
   - Set is_pending_sync = true → snapshot flower → plot.clear() → emit plots_updated
   - Await HTTP call to new endpoint
   - Success: finalize (is_pending_sync = false), call InventoryManager.restore_seed(flower_template_id)
   - Failure: rollback (plot.plant(snapshot), is_pending_sync = false, emit)

5. **Mode persistence** — dig_up_mode does NOT auto-exit after one dig. Player can dig multiple plots by tapping them in sequence. Toggling ShovelButton again or selecting another mode exits.

6. **Seed restoration function** — InventoryManager.restore_seed(flower_template_id: String) must create inventory entry if it doesn't exist (same rule as HarvestProduct per CLAUDE.md).

7. **No XP/currency** — dig_up grants neither (unlike harvest). Explicitly different outcome.

8. **No partial refund / audit log** — Out of scope per spec.

### File Touchpoints

**Godot client:**
- autoloads/InteractionManager.gd — Add mode enum, replace harvest_mode, add dig_up functions
- autoloads/GardenManager.gd — Add dig_up(plot_id) function with optimistic UI
- autoloads/InventoryManager.gd — Add restore_seed(flower_template_id) function
- scenes/garden/Plot.gd (PlotNode class) — Add dig_up tap handler + confirm dialog
- scenes/hud/HUD.gd — Wire ShovelButton.pressed signal

**Backend (eco-backend, D:\GitHub\eco-backend):**
- API/Controllers/GardenController.cs — Add DigUpFlower(plotId) action
- Application/Services/GardenService.cs — Add DigUpFlowerAsync(userId, plotId) method
- (Domain entities, repositories already exist; no schema changes needed)

## Dependencies

- BE endpoint must be fully deployed before mobile APK can test dig-up feature.
- Seed restoration is implemented as inline logic directly in `GardenService.DigUpFlowerAsync`, using public `IInventoryRepository` primitives (`GetInventoryItemByFlowerTemplateIdAsync`, `AddInventoryItemAsync`, `UpdateInventoryItem`) — corrected from the original assumption that `InventoryService.UpsertInventoryItemAsync()` could be reused; that method is private and not exposed on the repository interface, and `InventoryItem` has no Category field (type is disambiguated purely by which FK is non-null).
- BaseDialog component already supports confirm + cancel signals.
- No new external services or data migrations required.

## Risks

- **HIGH: Data loss on network failure** — If HTTP request fails after optimistic clear, client must rollback correctly to avoid permanently losing the planted flower. Mitigation: snapshot PlantedFlower before any UI update, always restore on error; test with simulated 500 errors per spec success criteria.

- **MEDIUM: Mode toggle inconsistency** — If harvest_mode and dig_up_mode both use separate bools, player could trigger both simultaneously causing UX confusion. Mitigation: refactor to single enum CurrentMode before wiring any buttons, verify mode exclusivity in unit tests.

- **MEDIUM: Confirm dialog double-trigger** — Player taps plot twice quickly during modal animation; dialog fires twice. Mitigation: Plot.gd checks is_pending_sync before calling dig_up (already in other tappers); lock plot interaction during dialog lifetime via input_blocked flag.

- **MEDIUM: Seed item creation edge case** — If InventoryManager tries to restore_seed() for a flower_template_id never seen before, the inventory item must be created (not just incremented). Mitigation: BE inline upsert (Phase 1) creates a fresh `InventoryItem { FlowerTemplateId, Quantity = 1 }` when `GetInventoryItemByFlowerTemplateIdAsync` returns null — no Category field exists or is needed, since FlowerTemplateId alone identifies the seed; mirror the same create-if-absent logic client-side in `InventoryManager.restore_seed()`; test with fresh account.

- **LOW: Endpoint response format drift** — BE may return slightly different JSON shape from harvest response. Mitigation: follow existing HarvestFlower pattern exactly, matching all field names and nesting; code-review GardenService against this plan before implementation.

- **LOW: Async sequencing** — If two dig-ups fire concurrently, plots could desync. Mitigation: is_pending_sync flag prevents concurrent requests on same plot (checked in GardenManager.dig_up() guard); plot-level lock sufficient since backend ownership check prevents user A digging user B's plot.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-21 23:00
**Phase in progress:** none — Phases 1-4 complete, Phase 5 deferred to user
**Status:** All 4 implementation phases done and Review-Gate-approved. `code-reviewer` sub-agent (ck-cook Step 4, --hard mode) returned **APPROVED** with 0 Critical/High/Medium/Low findings across all BE and client files, independently re-verifying the lambda-capture fix, the BaseDialog hang fix, `is_pending_sync` cleanup on every path, and the BE FK-only InventoryItem handling. Phase 5 (15-test manual checklist) requires actual Godot gameplay (UI taps, confirm dialogs, simulated network failures) — no Godot CLI in this environment, so the user will run it themselves outside this pipeline. **User explicitly chose to hold off on git commit** until after their own manual testing — no commit has been made.

### Decisions made this session (Phase 4)
- **Confirmed `ShovelButton` exists** at `RightIconGrid/ShovelButton` in `HUD.tscn` (with child `ShovelIcon` TextureRect) before wiring — matches plan's mandated Step 1 check.
- **`GardenManager.dig_up()` and the `"dig_up"` dispatcher case were already present** from Phase 3 work (verified via grep) — no duplicate work needed for step 6 of this phase.
- **Real bug caught and fixed in the plan's own code sample**: the `_try_dig_up()` template used `var confirmed := false` with `func(): confirmed = true` inside two one-shot lambda connections. GDScript captures local variables by value in lambdas, so this reassignment silently never propagates to the outer scope — confirmed by an IDE diagnostic (`CONFUSABLE_CAPTURE_REASSIGNMENT`) the moment the code was typed. Fixed by boxing the flag in a single-element `Array` (`var result := [false]`), since arrays are reference types and `result[0] = true` inside the lambda correctly mutates the shared box. Updated both the implementation and `phase-04-hud-plot-wiring.md`'s code sample to match.
- `ShovelButton` added to `HUD.gd`'s `_sync_modal_chrome()` visibility-hiding logic (mirroring `_harvest_btn`) — not explicitly in the original plan text but consistent with the established pattern for action-mode buttons during modals.
- `_on_dig_up_mode_changed(active)` highlights `ShovelButton` with `Color(0.8, 0.6, 0.2, 1.0)` (brownish, distinct from harvest's orange) when dig-up mode is active.
- `Plot.gd`'s `_on_plot_gui_input()` got a new `elif InteractionManager.is_dig_up_mode(): _try_dig_up()` branch alongside the existing harvest branch; `apply_drag_action()` was left unchanged since digging is tap-only per spec (no drag-triggered dig-up).

### Files changed across Phases 1-4 (for reference)
- BE: `Application\Helpers\Constant.cs`, `Application\DTOs\Garden\DigUpRewardDto.cs` (new), `Application\Interfaces\IGardenService.cs`, `Application\Services\GardenService.cs`, `API\Controllers\GardenController.cs`
- Godot: `autoloads/InteractionManager.gd` (enum CurrentMode refactor, `dig_up_mode_changed` signal), `autoloads/InventoryManager.gd` (`select_item()` generalized mode-exit + new `restore_seed()`), `autoloads/GardenManager.gd` (`dig_up()` + `_http_dig_up` plumbing + dispatcher case), `scenes/hud/HUD.gd` (`_shovel_btn` onready + wiring + `_on_dig_up_mode_changed` + modal-chrome visibility), `scenes/garden/Plot.gd` (`_try_dig_up()` + tap-handler branch).

### Next immediate action
None from this pipeline. User runs `phase-05-manual-verification.md`'s 15-test checklist on their own; if any test fails, resume here (re-open this plan) rather than starting a new one. No git commit has been created — create one once the user is satisfied with manual testing (or asks for it sooner).

### From plan-reviewer (NOTED — acknowledged, no plan change required)

- **No XP/currency compensation on dig-up** — confirmed out of scope per spec; players digging up a high-stage plant get only 1 seed back. If this becomes a complaint, revisit as a separate feature (would need new DTO fields + BE logic) — not blocking for v1.
- **No UI hint distinguishing "dig-up works at any stage" vs "harvest only at max stage"** — confirm dialog already states the consequence ("mất toàn bộ stage/XP"); a tooltip/info-panel hint would be a UX polish item, not required for the spec's success criteria.
- **BE response DTO schema versioning** — no formal contract test today; if `DigUpRewardDto` gains fields later, keep them nullable/optional and have the Godot client read fields defensively (already required by Phase 3's malformed-JSON handling).
- **Phases are sequential in this plan but could parallelize** — Phases 2–4 (Godot) can be developed against `use_mock = true` before Phase 1 (BE) is deployed, then switched to the real endpoint for Phase 5. Not required, just an option if timeline pressure appears.
