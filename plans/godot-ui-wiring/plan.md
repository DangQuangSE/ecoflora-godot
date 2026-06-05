# Plan: Godot UI Wiring — Currency, Vitality Bar, Shop

**Status:** In Progress
**Date:** 2026-06-04
**Scope:** Wire scripts → scene files. All GDScript đã viết xong. Chỉ cần tạo/chỉnh .tscn và chuẩn bị assets.

## Assets bạn cần chuẩn bị

| File path | Kích thước | Dùng cho |
|---|---|---|
| `assets/icon/coin.png` | 32×32 px | CoinLabel trên UserHUD |
| `assets/icon/heart.png` | 48×48 px | HeartIcon trong VitalityBar |
| `assets/icon/shop.png` | 64×64 px | ShopButton trên HUD |
| `assets/icon/pesticide.png` | 64×64 px | Item icon (đang fallback bag.png) |

> Icons đã có: `watering_can.png`, `fertilizer.png`, `sickle.png`, `bag.png`

---

## Phases

- [x] Phase 1: Modify `UserHUD.tscn` — thêm CoinLabel + coin icon
- [x] Phase 2: Create `VitalityBar.tscn` — heart + fill bar + countdown + claim button
- [x] Phase 3: Modify `HUD.tscn` — thêm ShopButton + instance VitalityBar
- [x] Phase 4: Create `ShopItemCard.tscn` — reusable item card
- [x] Phase 5: Create `ShopScene.tscn` — full screen shop với tabs

---

## Node structure tóm tắt

```
UserHUD (Panel) [160×96]
├── AvatarRect (ColorRect)          ← giữ nguyên
├── LevelLabel (Label)              ← giữ nguyên
├── XPBar (ProgressBar)             ← giữ nguyên
├── CoinIcon (TextureRect)          ← MỚI — res://assets/icon/coin.png
└── CoinLabel (Label)               ← MỚI — "$CoinLabel" in UserHUD.gd

VitalityBar (Control) [280×44]
└── HBoxContainer
    ├── HeartIcon (TextureRect)     ← res://assets/icon/heart.png
    ├── FillBar (ProgressBar)       ← max=21600, "$FillBar"
    ├── CountdownLabel (Label)      ← "$CountdownLabel"
    └── ClaimButton (Button)        ← text="Nhận", "$ClaimButton"

HUD (CanvasLayer)                   ← existing
├── ... (existing nodes)
├── ShopButton (Button)             ← MỚI — "$ShopButton", icon=shop.png
└── VitalityBar (instance)          ← MỚI — instance VitalityBar.tscn

ShopItemCard (PanelContainer) [120×140]
├── VBoxContainer
│   ├── ItemIcon (TextureRect)      ← 96×96
│   ├── NameLabel (Label)
│   └── PriceLabel (Label)
└── TapArea (Button)                ← full rect, flat, "$TapArea"

ShopScene (Control) [full screen]
├── BackButton (Button)             ← "$BackButton"
├── TabContainer                    ← "$TabContainer"
│   ├── Consumables (ScrollContainer)
│   │   └── GridContainer (columns=2)
│   ├── Hạt giống (ScrollContainer)
│   │   └── GridContainer (columns=2)
│   └── Trang trí (ScrollContainer)
│       └── GridContainer (columns=2)
├── LoadingSpinner (Label)          ← "$LoadingSpinner"
└── ConfirmDialog (Panel)           ← "$ConfirmDialog"
    ├── ItemNameLabel (Label)       ← "$ConfirmDialog/ItemNameLabel"
    ├── PriceLabel (Label)          ← "$ConfirmDialog/PriceLabel"
    ├── ConfirmButton (Button)      ← "$ConfirmDialog/ConfirmButton"
    └── CancelButton (Button)       ← "$ConfirmDialog/CancelButton"
```
