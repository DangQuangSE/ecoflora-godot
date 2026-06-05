# Spec: Shop Navigation

**Status:** Ready for planning
**Date:** 2026-06-05

## Problem

Người chơi không có cách nhanh để vào tab mua coin. Click coin trong UserHUD không làm gì. ShopScene chỉ mở ở tab 0 mặc định.

## User Stories

| # | Story | Priority |
|---|-------|----------|
| 1 | Click ShopButton trong HUD → ShopScene mở tại tab 0 (Tiêu hao) | P1 |
| 2 | Click vùng coin (CoinIcon + CoinLabel) trong UserHUD → ShopScene mở tại tab 3 (Nạp Coin) | P1 |
| 3 | Tab "Nạp Coin" tồn tại trong ShopScene với placeholder UI | P1 |
| 4 | ShopButton click không bị ảnh hưởng bởi flag | P1 |

## Success Criteria

- Tap CoinButton → ShopScene.current_tab == 3 (verified bằng mắt)
- Tap ShopButton → ShopScene.current_tab == 0
- `UserManager.shop_open_tab` luôn = 0 sau khi ShopScene `_ready()` chạy
- Không regression: tab 0, 1, 2 vẫn load đúng catalog

## Architecture

### Flag convention
```gdscript
# Trước khi change_scene:
UserManager.shop_open_tab = 3  # hoặc 0

# Đầu ShopScene._ready():
_tab_container.current_tab = UserManager.shop_open_tab
UserManager.shop_open_tab = 0  # reset ngay lập tức
```

### Files thay đổi

| File | Thay đổi |
|------|---------|
| `autoloads/UserManager.gd` | Thêm `var shop_open_tab: int = 0` |
| `scenes/hud/UserHUD.tscn` | Thêm `CoinButton` (flat Button) bao quanh CoinIcon + CoinLabel |
| `scenes/hud/UserHUD.gd` | Thêm `_coin_btn` @onready, connect pressed → set flag + change_scene |
| `scenes/shop/ShopScene.tscn` | Thêm tab thứ 4: "Nạp Coin" (ScrollContainer → placeholder Label) |
| `scenes/shop/ShopScene.gd` | `_ready()`: đọc `UserManager.shop_open_tab`, set tab, reset |

### CoinButton trong UserHUD.tscn
- Đặt bao quanh CoinIcon (left=21, top=123, right=53, bottom=152) và CoinLabel
- `flat = true`, `mouse_filter = 0`
- Giữ nguyên CoinIcon và CoinLabel như sub-nodes hoặc bên cạnh

## Out of Scope

- Backend/logic nạp coin thật
- Animation khi mở đúng tab
- IAP integration
