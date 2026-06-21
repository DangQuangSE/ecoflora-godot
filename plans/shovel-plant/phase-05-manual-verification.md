# Phase 5: Manual End-to-End Verification

## Requirements

Comprehensive manual testing of all dig-up feature flows (success, cancellation, failure/rollback, mode persistence, consecutive digs) against the spec's success criteria. Verify that the feature behaves exactly as described in the spec without data loss or UX glitches.

## Steps

1. **Pre-test setup** — Build and deploy eco-backend with the new DigUpFlower endpoint (Phase 1) to a test server. Configure Godot `UserManager.base_url` to point to that server. Ensure a test account with a populated garden (at least 3 occupied plots with different flowers at different stages). Log in and sync the garden state.

2. **Test 1: Enter dig_up_mode and verify visual highlight** — In the garden scene, tap the ShovelButton. Verify: (a) button highlights with the designated color (brownish/gold); (b) HUD label or visual changes to indicate mode active; (c) previously selected item (if any) is deselected (InventoryManager.deselect called); (d) harvest_mode is deactivated (harvest button returns to white).

3. **Test 2: Tap occupied plot in dig_up_mode and verify confirm dialog** — Tap any occupied plot. Verify: (a) BaseDialog appears with title "Xúc cây"; (b) message text includes the flower name (e.g., "Rose") and warns about stage/XP loss; (c) two buttons visible: "Xúc" (gold/confirm) and "Hủy" (cancel); (d) dialog backdrop dims the garden; (e) garden input is blocked (tapping outside dialog does nothing); (f) plot sprite does not respond while dialog is open.

4. **Test 3: Cancel dig_up via dialog "Hủy" button** — Click "Hủy" button. Verify: (a) dialog closes with pop-out animation; (b) garden input resumes; (c) plot remains occupied (flower sprite visible, stage label unchanged); (d) seed count in inventory unchanged; (e) dig_up_mode is STILL ACTIVE (button still highlighted); (f) can tap another plot to show another confirm dialog without re-toggling button.

5. **Test 4: Confirm dig_up and verify optimistic UI** — Tap an occupied plot, click "Xác nhận" or "Xúc" button in the dialog. Verify: (a) dialog closes; (b) plot becomes visibly empty WITHIN 1 frame (plant sprite vanishes, stage label hidden, plot texture returns to normal/non-watered image); (c) toast appears saying "Xúc cây thành công."; (d) is_pending_sync flag is temporarily true (can verify by looking at plot state in debug); (e) within <5 seconds (or immediately on fast network), seed count in inventory increases by 1 for that flower type.

6. **Test 5: Verify seed restored matches flower type** — Pick a plot with Rose Lv.3, confirm dig_up. Check inventory: Rose seed count incremented by 1. Repeat with different flower (e.g., Tulip Lv.2). Verify: each flower's seed count increases independently, matching the dug flower's template_id.

7. **Test 6: Consecutive dig-ups in same mode** — Without toggling button again, tap a second occupied plot, confirm. Verify: (a) confirm dialog shows for the new plot; (b) after dig_up, that plot is empty and its seed added to inventory; (c) dig_up_mode remains active (button still highlighted); (d) can tap a third plot immediately after and dig it up as well. Perform at least 3 consecutive digs to confirm persistence.

8. **Test 7: Exit dig_up_mode by toggling button again** — While dig_up_mode is active, tap ShovelButton. Verify: (a) button returns to white (no highlight); (b) tapping an occupied plot now shows flower info panel instead of confirm dialog; (c) mode is reset to NONE.

9. **Test 8: Exit dig_up_mode by switching to harvest_mode** — Enable dig_up_mode (button highlighted). Tap a consumable/care item in inventory (water/fertilize). Verify: (a) dig_up_mode automatically disables (button returns to white); (b) tapping occupied plot now applies the care item, not dig_up; (c) mode is reset to NONE.

10. **Test 9: Simulate network failure and verify rollback** — Reproduce via `GardenManager.use_mock = true` + a forced error branch in the mock dig_up path (preferred, deterministic) or a proxy tool (Charles/Fiddler) against a real backend (less reproducible — only use if mock injection isn't available). Run three variants, each verifying the same rollback outcome (a–f below):
    - **9a — HTTP 500:** force the mock/proxy to return 500.
    - **9b — Timeout:** force a response delay longer than `_http_dig_up.timeout` (15s) or set timeout lower for the test; confirm the client treats a timeout identically to an error response (not a hang).
    - **9c — 401 Unauthorized:** force a 401; confirm `UserManager.handle_401()` fires AND the plot still rolls back (don't assume the 401 handler alone covers plot state restoration).

    For each variant, tap an occupied plot while dig_up_mode active, confirm dialog, click "Xúc". Verify: (a) plot appears empty optimistically for ~1 second; (b) error toast appears saying "Xúc cây thất bại. Vui lòng thử lại." (9c may show a different message via the 401 handler — verify it doesn't leave the plot stuck either way); (c) plot reverts to showing the original flower (rollback) with stage/XP/timestamps matching pre-dig-up state exactly (per Phase 3's deep_copy fix); (d) seed count in inventory remains unchanged (no seed added); (e) plot is now usable again (not stuck in pending_sync state); (f) dig_up_mode remains active (button still highlighted, can try again or try another plot).

11. **Test 10: Verify no XP or currency changes on dig_up** — Before dig_up, note user's XP/Level (check UserManager or user profile panel) and currency. Perform a dig_up on an occupied plot. After success, verify: (a) user XP/Level unchanged; (b) currency unchanged; (c) NO user-level notifications about XP gain (unlike harvest, which shows "+ currency" toast).

12. **Test 11: Empty plot behavior in dig_up_mode** — Tap an empty/unoccupied plot while dig_up_mode active. Verify: (a) no confirm dialog appears; (b) no toast shown; (c) plot does not respond (gracefully ignored); (d) mode remains active.

13. **Test 12: Dig_up_mode persistence across scene transitions** — Enable dig_up_mode. Open inventory panel (or shop panel) — modals should hide HUD buttons temporarily. Close modal. Verify: (a) dig_up_mode is still active (button still highlighted); (b) can immediately tap a plot to dig_up without re-toggling.

14. **Test 13: Login/logout resets mode** — Enable dig_up_mode. (Simulate logout if possible, or open settings and trigger account switch.) Verify: (a) dig_up_mode is reset to NONE (button returns to white); (b) on re-login, mode is NONE (starting fresh).

15. **Verification against spec success criteria** — For each spec success criterion (doc line 54–60), run the exact test scenario and document the result:
    - ✓ Bấm ShovelButton → mode active, tap occupied → popup confirm hiện đúng style.
    - ✓ Xác nhận xúc → plot trống <1 frame, seed +1 sau khi API trả về.
    - ✓ Hủy → plot/inventory không đổi, mode vẫn active.
    - ✓ Xúc liên tiếp 2 ô → mode vẫn active sau lần 1.
    - ✓ API lỗi 500 → plot rollback, không mất cây.

## Success Criteria

- All 15 manual tests pass without crashes or data corruption.
- Plot state (occupied/empty, flower presence, stage) correctly reflects dig_up outcome across all scenarios.
- Seed inventory correctly incremented (only on success, not on failure/rollback).
- User XP/Level/Currency unchanged by dig_up actions.
- dig_up_mode remains active until explicitly toggled off or mode switched.
- Confirm dialog appears only in dig_up_mode and only for occupied plots.
- No toast message appears for empty plots (graceful no-op).
- Network failure + rollback leaves plot in consistent state (not stuck in pending_sync).
- Toast messages are clear and correct for each outcome (success, failure, already max stage).
- No visual glitches or layout shifts during dialog pop-in/pop-out animations.

## Risks

- **Non-deterministic test failures** — Network latency or server timing issues might cause flaky tests. Mitigation: Run tests on a local/controlled network; use mock mode for Phase 1 and 2 testing before e2e testing; document expected latencies.
- **Incomplete rollback** — If partial state was committed before failure, rollback may not fully restore the plot. Mitigation: Backend transaction ensures atomicity (either both flower deleted and seed added, or neither); client snapshot ensures rollback completeness. Verify both layers before Phase 5.
- **Platform-specific issues** — UI/input behavior might differ on Android vs. desktop. Mitigation: Test on target platform (Android APK) after desktop verification; note any platform-specific workarounds.
- **Data retention after crash** — If Godot process crashes mid-dig_up (while is_pending_sync=true), is state recovered correctly on restart? Mitigation: This is a known GDScript limitation; document as acceptable risk. Optimistic UI means <1% chance of crash during the window.
