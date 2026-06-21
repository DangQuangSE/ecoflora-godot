# Phase 3: Godot Client GiftCodeManager Autoload and Redemption UI

## Requirements

Implement a GiftCodeManager autoload following TaskManager.gd pattern that calls the backend redeem endpoint, applies rewards via UserManager and InventoryManager, emits signals for UI feedback, and create a minimal input dialog scene for players to enter gift codes.

## Steps

1. Create GiftCodeManager.gd as a new autoload (register in project.godot after TaskManager; must load after UserManager).

2. Implement RedeemAsync(code: String) method in GiftCodeManager: normalize code client-side with `code.to_upper().strip_edges()` (must match backend's `Trim().ToUpper()` normalization exactly, per phase-02 step 2 — same casing/whitespace rules on both sides so a code typed with stray spaces still matches), call HTTPRequest to POST /gift-codes/redeem with {code} body, handle 401/error responses via UserManager.handle_401(), parse response envelope and GiftCodeRedeemResultDto, cache result. The redeem is server-side idempotent (unique constraint on UserId+GiftCode) — if the HTTP request times out or the connection drops AFTER the server already committed the redemption, a retry of the same request is safe: the server will return `AlreadyRedeemed` rather than granting twice.

3. On successful redeem response, apply NewCurrencyTotal via UserManager.update_currency(new_total), then iterate granted reward items and call InventoryManager.add_reward_item(item_id, item_name, qty) for each.

4. Emit a redeem_result_received signal with success/error code so UI can display toast/dialog feedback (mirroring TaskManager.claim_result_received signal on line 4).

5. Create a GiftCodeRedeemDialog.tscn scene with LineEdit (code input), Button (redeem), Label (status/error), matching flow-flora UI style — minimal, no custom art required.

6. Hook redeem button to call GiftCodeManager.RedeemAsync(), disable button while in-flight (mirroring `TaskManager._claim_in_flight`), display error message for invalid/expired/quota/already-redeemed codes, emit inventory_updated signal after success. On a network error/timeout (HTTPRequest fails before any HTTP status is received — not a parsed AlreadyRedeemed/Expired/etc. response), do NOT clear the in-flight flag and re-enable the button for an immediate retry; instead show "Network error — please check your connection" and require the user to close and reopen the dialog before trying again. Rationale: the server may have already committed the redemption right before the connection dropped, so the client cannot tell "never reached server" apart from "succeeded but response lost" — forcing a dialog reopen triggers GiftCodeManager to resync user currency/inventory from the server profile rather than silently treating a lost-response success as a fresh failed attempt.

7. Connect GiftCodeManager.redeem_result_received signal in GiftCodeRedeemDialog to show toast or close dialog on success.

8. Create a GiftCodeService.gd in services/ to encapsulate HTTP logic (request serialization, response parsing) mirroring DailyTaskService.gd structure.

9. Register GiftCodeManager in project.godot autoloads.

## Success Criteria

- GiftCodeManager.redeem_async(code) successfully calls backend and applies reward to user currency and inventory.
- Concurrent redeem calls are serialized (only one in-flight at a time, subsequent calls return early, matching TaskManager._claim_in_flight pattern).
- UI dialog appears with code input field, displays success/error feedback, emits inventory_updated after reward applied.
- Signal redeem_result_received is emitted with error code distinguishing NotFound/Expired/AlreadyRedeemed/QuotaExceeded/Success for proper UI messaging.

## Testing

- **Manual Test (Offline Mock)**: With GiftCodeManager.use_mock = true, redeem returns a mock reward; verify currency and inventory updated in-memory.
- **Manual Test (Online)**: Call GiftCodeManager.redeem_async("VALID_CODE") with a real backend; verify response parsed and reward applied to UserManager.currency and InventoryManager.
- **Manual Test (Error Cases)**: Redeem invalid/expired/exhausted code; verify error message displayed in dialog without crashing.
- **Manual Test (UI)**: Open GiftCodeRedeemDialog, type code, click Redeem, verify UI updates (button disabled, loading indicator, success/error text).
- **Manual Test (Concurrency)**: Click Redeem multiple times rapidly; verify only first request is sent; subsequent clicks ignored until first completes.
- **Manual Test (Already Redeemed)**: Redeem valid code successfully, redeem same code again; verify "Already Redeemed" error message displayed.
- **Manual Test (Signal Wiring)**: Verify InventoryManager.inventory_updated signal fires after successful redeem (check via autoload inspector or debug output).

## Risks

- Race condition if player closes dialog during HTTP request — Mitigation: Disable close button while in-flight; cancel request on _exit_tree().
- Code normalization mismatch (client sends differently than backend normalizes) — Mitigation: Normalize code in GDScript (uppercase, trim) before sending; match backend logic exactly.
- Reward parsing may fail if response DTO schema changes — Mitigation: Add schema validation; test with actual backend response JSON.
- Network failure after server-side commit but before client receives response (ambiguous outcome) — Mitigation: keep in-flight flag set on network error (no immediate retry), force dialog close/reopen to resync currency/inventory from server profile; redeem is server-side idempotent so a true retry of the same request is also safe (returns AlreadyRedeemed, never double-grants).
