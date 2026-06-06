# Spec: Shop UI Rebuild

**Status:** Ready for planning
**Date:** 2026-06-06

## Problem

ShopScene dùng TabContainer mặc định của Godot — không thể dùng ảnh gỗ làm tab, không tùy chỉnh visual được. Cần rebuild hoàn toàn bằng asset ảnh thực tế (`shop_bg.png`, `shop_tab.png`, `shop_card.png`).

## User Stories

| # | Story | Priority |
|---|-------|----------|
| 1 | ShopPanel hiển thị `shop_bg.png` làm nền toàn bộ khung shop | P1 |
| 2 | 4 TextureButton tabs (Tiêu hao / Hạt giống / Trang trí / Nạp Coin) dùng `shop_tab.png` normal, `shop_tab_clicked.png` khi active | P1 |
| 3 | Nhấn tab → `queue_free()` toàn bộ card trong GridContainer → `render_shop_items(items)` từ mock data | P1 |
| 4 | `render_shop_items()` instantiate ShopCard với `shop_card.png` làm nền (NinePatchRect), điền name, price, icon | P1 |
| 5 | GridContainer 3 cột, card tự scale theo chiều rộng | P1 |
| 6 | Mock data đủ 4 tab, cấu trúc `Array[Dictionary]` với keys: `id, name, price, icon_path` | P1 |
| 7 | Header (Back + Currency) giữ nguyên như hiện tại | P2 |
| 8 | ConfirmDialog / Toast giữ nguyên logic như hiện tại | P2 |

## Success Criteria

- Tap tab → grid clear và hiển thị đúng items trong vòng 1 frame
- `shop_bg.png` fill ShopPanel không bị stretch méo (dùng `expand_mode` hoặc `stretch_mode` phù hợp)
- `shop_tab_clicked.png` hiển thị trên tab đang active, `shop_tab.png` trên các tab còn lại
- GridContainer có đúng 3 columns
- `shop_card.png` visible làm nền mỗi card
- Không regression: BackButton, BalanceLabel, ConfirmDialog, Toast vẫn hoạt động

## Architecture

### Node tree mới

```
ShopScene (Control, fullscreen)
  BG (ColorRect, fullscreen dark overlay)
  Header (Panel, y=0..72)
    BackButton / TitleRow / CurrencyBox  ← giữ nguyên
  ShopPanel (Control, y=72..1280)
    ShopBg (TextureRect, shop_bg.png, fill ShopPanel)
    TabGroup (HBoxContainer, vị trí tabs trên ảnh nền)
      TieuHaoBtn (TextureButton)
      HatGiongBtn (TextureButton)
      TrangTriBtn (TextureButton)
      NapCoinBtn  (TextureButton)
    ScrollContainer (vùng card slots trên ảnh nền)
      GridContainer (columns=3)
  ConfirmOverlay / ConfirmDialog / ToastNotification  ← giữ nguyên
  LoadingSpinner  ← giữ nguyên
```

### Mock data

```gdscript
const _MOCK: Dictionary = {
    0: [  # Tiêu hao
        {"id":"water",      "name":"Nước tưới", "price":10, "icon_path":"res://assets/icon/watering_can.png"},
        {"id":"fertilizer", "name":"Phân bón",  "price":20, "icon_path":"res://assets/icon/fertilizer.png"},
        {"id":"pesticide",  "name":"Thuốc sâu", "price":20, "icon_path":"res://assets/icon/sickle.png"},
    ],
    1: [  # Hạt giống
        {"id":"seed_rose",      "name":"Hạt hồng",   "price":50, "icon_path":""},
        {"id":"seed_sunflower", "name":"Hạt hướng dương", "price":40, "icon_path":""},
    ],
    2: [],  # Trang trí — placeholder
    3: [],  # Nạp Coin — placeholder
}
```

### render_shop_items flow

```gdscript
func _on_tab_pressed(idx: int) -> void:
    _set_active_tab(idx)
    _render_items(_MOCK.get(idx, []))

func _render_items(items: Array) -> void:
    for child in _grid.get_children():
        child.queue_free()
    var balance := UserManager.get_profile().currency
    for d in items:
        var item := ShopItem.new()
        item.id = d["id"]; item.name = d["name"]
        item.price = d["price"]; item.image_url = d["icon_path"]
        item.is_active = true
        var card: ShopItemCard = ShopCardScene.instantiate()
        _grid.add_child(card)
        card.setup(item, balance)
        card.tapped.connect(_on_item_tapped)
```

### ShopItemCard update

- Thay `PanelContainer` + `StyleBoxFlat` background → `NinePatchRect` với `shop_card.png`
- Logic `.setup()`, `.set_affordable()`, `.item_price()`, signal `tapped` giữ nguyên

### Files thay đổi

| File | Thay đổi |
|------|---------|
| `scenes/shop/ShopScene.tscn` | Rebuild: bỏ TabContainer, thêm ShopPanel + TabGroup + ScrollContainer |
| `scenes/shop/ShopScene.gd` | Rewrite: TextureButton tabs, mock data, `_render_items()` |
| `scenes/shop/ShopItemCard.tscn` | Thay StyleBoxFlat bg → NinePatchRect shop_card.png |
| `scenes/shop/ShopItemCard.gd` | Không đổi logic, chỉ update node paths nếu TSCN thay đổi |

## Notes

- TabGroup và ScrollContainer cần căn chỉnh vị trí pixel thủ công trong Godot editor theo shop_bg.png thực tế
- NinePatchRect `patch_margin_*` cần thử trong editor để không vỡ ảnh card
- Khi có API thật: `_MOCK` replace bằng `UserManager.get_shop_catalog_async()`, convert flow giữ nguyên

## Out of Scope

- API integration thật
- Animation khi chuyển tab
- ConfirmDialog / Toast redesign
