# Phase 2: UserHUD Coin Button

## Requirements
The coin area in UserHUD (CoinIcon + CoinLabel) becomes tappable. Tapping it sets `UserManager.shop_open_tab = 3` then navigates to ShopScene. The existing ShopButton tap (tab 0) is unaffected.

## Steps
1. Open `scenes/hud/UserHUD.tscn` and add a flat Button node (named `CoinButton`) that covers the CoinIcon and CoinLabel area (anchor region: left=21, top=123, right=53, bottom=152); set `flat = true` and `mouse_filter = 0`.
2. Make CoinIcon and CoinLabel children of (or siblings behind) CoinButton so the visual display is preserved.
3. In `scenes/hud/UserHUD.gd`, add an `@onready` reference to `CoinButton` and connect its `pressed` signal in `_ready()`.
4. Implement the pressed handler: set `UserManager.shop_open_tab = 3`, then call `get_tree().change_scene_to_file(...)` pointing to ShopScene.
5. Manually test in-editor: tap CoinButton → ShopScene opens, tap ShopButton → ShopScene opens at tab 0 (no regression).

## Success Criteria
- Tapping the coin area in UserHUD opens ShopScene with tab index 3 active
- Tapping ShopButton still opens ShopScene at tab 0
- `UserManager.shop_open_tab` is 0 after ShopScene finishes `_ready()` (verified in phase 3)
- No existing HUD controls lose mouse input due to overlap

## Risks
- Button overlap blocking other HUD touch areas: mitigated by keeping CoinButton bounds tight to the coin region and verifying adjacent controls still respond
- scene path string mismatch for ShopScene: mitigated by copying the exact path already used by the existing ShopButton handler
