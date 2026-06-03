# Phase 5: Godot Scenes (HUD + Shop)

**Codebase:** Godot project (`d:\DOCUMENTFPT\SEMESTER_8\EXE2\flow-flora-godot\`)

## Requirements
Players can see their coin balance at all times in the top-bar HUD, view and interact with the vitality bar, and navigate a shop scene to browse and purchase items — all updating in real-time from UserManager signals without any direct Manager→View calls.

## Steps
1. Extend `scenes/hud/UserHUD.tscn`: add a horizontal row below the XP bar containing a coin icon (`TextureRect` or `Label` with emoji) and a `CoinLabel` (`Label`). Adjust the Panel height as needed. The existing `UserHUD.gd` must connect `UserManager.currency_changed` in `_ready()` and disconnect it in `_exit_tree()`. Add `_on_currency_changed(new_amount: int)` to update `CoinLabel.text = str(new_amount)`. Call `_refresh()` to show initial value on load.
2. Create `scenes/hud/VitalityBar.tscn` as a standalone sub-scene (not inline in UserHUD). Node structure: root `Panel` → `HBoxContainer` containing a heart `TextureRect`, a `ProgressBar` (min 0, max 21600 = 6h in seconds), a countdown `Label`, and a `ClaimButton` (`Button`). The bar grows left-to-right; value = `21600 - seconds_until_ready`.
3. Create `scenes/hud/VitalityBar.gd`: in `_ready()` connect `UserManager.vitality_ready` to `_on_vitality_ready` and `UserManager.vitality_claimed` to `_on_vitality_claimed`. **Call `UserManager.request_vitality_status_async()` at the end of `_ready()` to hydrate the initial state immediately** — do not wait 60s for the next poll tick. Add a local 1-second `Timer` to decrement the countdown label and update `ProgressBar.value` each tick (compute from `UserManager.get_profile().vitality_ready_at`). Enable `ClaimButton` only when `UserManager.get_profile().is_vitality_ready()`. `ClaimButton.pressed` calls `UserManager.claim_vitality_async()`.
4. Instance `VitalityBar.tscn` inside `scenes/hud/HUD.tscn` (the top-level HUD scene that contains UserHUD) so it appears in the garden view. Position it to the right of UserHUD or below it — confirm with layout. The vitality bar is a sub-scene so it can be hidden independently for scenes that don't need it (e.g., classroom).
5. Create `scenes/shop/ShopScene.tscn` + `ShopScene.gd`. Layout: full-screen `Control` → `VBoxContainer` with a back button at top, a `TabContainer` with three tabs (Consumables, Seeds, Decorations), each tab containing a `ScrollContainer` → `GridContainer` of `ShopItemCard` instances. Add a purchase confirmation `AcceptDialog` (or custom `Panel`) that shows item name, price, and confirm/cancel buttons.
6. Create `scenes/shop/ShopItemCard.tscn` (reusable card sub-scene): `PanelContainer` → `VBoxContainer` with `TextureRect` (icon), `Label` (name), `Label` (price with coin icon). The card emits a `tapped(item: ShopItem)` signal when pressed. In `ShopScene.gd`, connect each card's `tapped` signal to open the confirmation dialog. On confirm, call `UserManager.purchase_async(item)` which internally calls `ShopService.purchase_async()` and on success calls `update_currency()` + optionally `apply_server_xp()` from the receipt.
7. Add a "coming soon" visual state to the Decorations tab: disable all cards and show a `Label` overlay reading "Coming Soon" if the category is Decoration. This avoids implementing garden placement in this phase.
8. **Add a shop entry point:** In `scenes/hud/HUD.tscn`, add a shop icon `TextureButton` (or `Button` with icon texture) to the HUD top bar. On `pressed`, call `get_tree().change_scene_to_file("res://scenes/shop/ShopScene.tscn")` (or push via the existing scene transition/layer system if one exists). Confirm the back button in `ShopScene.gd` calls `get_tree().change_scene_to_file("res://scenes/garden/GardenScene.tscn")` (or equivalent).

## Success Criteria
- After any currency change event, `CoinLabel` in UserHUD updates within the same frame (signal fires synchronously in the same process tick).
- VitalityBar countdown label counts down correctly: 1 second per real second, confirmed by waiting 10s and checking the label decreased by 10.
- `ClaimButton` is disabled when `secondsUntilReady > 0` and enabled when the server reports `isReady: true`.
- Tapping `ClaimButton` once triggers `claim_vitality_async()`. Tapping a second time before the response returns has no effect (button is disabled or `_claim_in_flight` guard drops the call).
- Reward toast appears after a successful claim, showing the correct `rewardType` and `rewardAmount`.
- ShopScene displays items loaded from `ShopService.get_catalog_async()` grouped by tab.
- Buying a consumable with sufficient currency: confirmation dialog shows correct name and price; on confirm the `CoinLabel` updates to the new balance returned by the server.
- Buying with 0 currency: confirm button in dialog is disabled (client-side check against `UserManager.get_profile().currency`).
- Decorations tab shows items in a "coming soon" state — cards are visible but not purchasable.

## Risks
- `ShopScene` loads the full catalog on `_ready()` — on slow connections the grid will be empty briefly. Add a `LoadingSpinner` control that is visible until the async fetch completes, then hidden.
- `ShopItemCard` instances in GridContainer are created dynamically — ensure `queue_free()` is called on all existing cards before re-populating on tab switch to prevent duplicate cards.
- `VitalityBar` local 1-second timer runs even when the bar is not visible. Connect `visibility_changed` signal to start/stop the timer to avoid unnecessary processing when the HUD is hidden.

## Files

| File | Layer | Action |
|---|---|---|
| `scenes/hud/UserHUD.tscn` | scenes | Modify — add CoinIcon + CoinLabel nodes to the panel |
| `scenes/hud/UserHUD.gd` | scenes | Modify — connect `currency_changed`, add `_on_currency_changed`, update `_refresh()` |
| `scenes/hud/VitalityBar.tscn` | scenes | Create — heart icon, ProgressBar, countdown Label, ClaimButton |
| `scenes/hud/VitalityBar.gd` | scenes | Create — timer logic, signal subscriptions, claim button handler |
| `scenes/hud/HUD.tscn` | scenes | Modify — instance VitalityBar sub-scene, add shop icon button |
| `scenes/shop/ShopScene.tscn` | scenes | Create — full-screen shop with TabContainer |
| `scenes/shop/ShopScene.gd` | scenes | Create — catalog fetch, tab population, purchase dialog logic |
| `scenes/shop/ShopItemCard.tscn` | scenes | Create — reusable card sub-scene |
| `scenes/shop/ShopItemCard.gd` | scenes | Create — card data binding, tapped signal |
