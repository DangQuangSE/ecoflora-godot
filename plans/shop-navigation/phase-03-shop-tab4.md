# Phase 3: ShopScene Tab 4 + Read Flag

## Requirements
ShopScene gains a fourth tab labeled "Nạp Coin" with a placeholder UI, and its `_ready()` reads `UserManager.shop_open_tab` to jump to the correct tab before resetting the flag to 0.

## Steps
1. Open `scenes/shop/ShopScene.tscn` and add a fourth tab to the TabContainer; name the tab "Nạp Coin" and place a ScrollContainer with a placeholder Label inside it (e.g., "Tính năng nạp coin sắp ra mắt").
2. In `scenes/shop/ShopScene.gd`, at the top of `_ready()` (before any other tab logic), read `UserManager.shop_open_tab`, assign it to `_tab_container.current_tab`, then immediately reset `UserManager.shop_open_tab = 0`.
3. Confirm the reset happens unconditionally (value 0 assigned even when the incoming flag was already 0) so the flag never persists across multiple scene loads.
4. Run through all four tabs manually: verify tabs 0–2 still display their existing catalog correctly and tab 3 shows the placeholder.
5. Verify the full round-trip: tap CoinButton in HUD → ShopScene opens on tab 3 → navigate away and return via ShopButton → ShopScene opens on tab 0.

## Success Criteria
- Tab "Nạp Coin" is visible as the 4th tab in ShopScene
- `UserManager.shop_open_tab` equals 0 immediately after ShopScene `_ready()` completes, regardless of entry path
- Tabs 0, 1, and 2 load their catalog without regression
- Full round-trip tap test passes (CoinButton → tab 3, ShopButton → tab 0)

## Risks
- TabContainer index off-by-one if tabs were renumbered: mitigated by counting tabs in the scene tree and confirming "Nạp Coin" is index 3 after adding it
- `_tab_container` reference unset if node path changed: mitigated by checking the existing `@onready` path in ShopScene.gd before editing
