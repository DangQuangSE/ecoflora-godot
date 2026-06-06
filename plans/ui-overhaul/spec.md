# Spec: UI Asset Integration Overhaul

**Date:** 2026-06-04
**Status:** Ready

---

## Problem Statement

All UI scenes use StyleBoxFlat placeholder visuals (solid colors, no images). Design team has delivered PNG assets. Need to integrate them without breaking existing signal wiring or GDScript node references.

---

## User Stories

- **[P1]** As a player, I see the portal rendered with the real portal.png sprite so the entry point looks polished.
  Accepted when: Portal.tscn uses `assets/portal/portal.png`, no stretch distortion visible.

- **[P1]** As a player, I see my profile area (avatar frame, name strip, XP bar) using the design assets so the HUD looks branded.
  Accepted when: UserHUD.tscn shows pf_frame.PNG, pf_name.PNG, pf_exp.PNG with correct texture; all GDScript node refs ($LevelLabel, $XPBar, $CoinLabel) still resolve.

- **[P1]** As a player, I see the shop with the designed background, tab buttons, and item cards.
  Accepted when: ShopScene.tscn shows shop_bg.PNG full-screen, tabs use shop_tab.png / shop_tab_clicked.png, each ShopItemCard shows shop_card.png as background.

- **[P2]** As a player, texture scaling looks correct on 720×1280 portrait (no pixelation, no squish).
  Accepted when: All TextureRect stretch_mode set appropriately (KEEP_ASPECT_CENTERED or SCALE for backgrounds).

- **[P3]** _(Custom animations on tab switch — out of scope)_

---

## Functional Requirements

1. **FR-01 Portal**: Portal.tscn replaces `demo_portal.png` ext_resource with `portal.png`. Scale adjusted to match original collision shape.
2. **FR-02 UserHUD avatar**: AvatarRect (ColorRect) → TextureRect using `pf_frame.PNG`. Node name stays `AvatarRect` for backward compatibility.
3. **FR-03 UserHUD name strip**: Add TextureRect `NameBg` behind LevelLabel using `pf_name.PNG`.
4. **FR-04 UserHUD XP bar**: Use StyleBoxTexture with `pf_exp.PNG` as XPBar background style, or add TextureRect behind ProgressBar.
5. **FR-05 ShopScene background**: Add TextureRect `BgTexture` as first child of ShopScene, anchors 0→1, `pf_scale` stretch mode = SCALE, z_index -1 or placed before all other nodes.
6. **FR-06 ShopScene tabs**: TabContainer theme_override `tab_unselected` = StyleBoxTexture(shop_tab.png), `tab_selected` = StyleBoxTexture(shop_tab_clicked.png).
7. **FR-07 ShopItemCard**: Replace StyleBoxFlat_card with StyleBoxTexture(shop_card.png) on PanelContainer. Fallback: NinePatchRect wrapping VBoxContainer if PNG has 9-patch corners.
8. **FR-08 Node paths**: All `@onready` paths in .gd files must resolve after changes — verify each.

---

## Non-Functional Requirements

- **Compatibility**: Godot 4.x only, GDScript only
- **No behavior change**: Zero changes to signal connections, autoload calls, or game logic
- **Mobile**: All textures use `filter = false` (pixel art) or appropriate import setting for the art style

---

## Success Criteria

- [ ] Godot opens all modified .tscn files without errors
- [ ] `godot --headless --check-only` passes on all modified .gd files
- [ ] All 4 scenes render their PNG assets visible in-editor scene preview
- [ ] ShopScene tab switching still works (ShopScene.gd TabContainer signal unchanged)
- [ ] UserHUD signals from UserManager still update LevelLabel, XPBar, CoinLabel correctly

---

## Out of Scope

- VitalityBar.tscn — no new assets for this scene
- UserProfileCard.tscn — no dedicated assets; existing StyleBoxFlat stays
- InventoryPanel.tscn — no new assets
- Font/typography changes
- Animation or transition effects

---

## Assumptions

- PNG assets are already imported in Godot (`.import` files will auto-generate on first open)
- `portal.png` replaces `demo_portal.png` at same approximate visual size
- `pf_frame.PNG` is a border/overlay (transparent center) not a filled background
- `shop_card.png` can be used as StyleBoxTexture stretch without 9-patch margins defined in code

---

## [NEEDS CLARIFICATION]

- [ ] Do pf_name.PNG / pf_exp.PNG stack as separate layers, or is pf_name.PNG a full panel bg that contains both name+exp?
- [ ] shop_card.png: does it have defined 9-patch margins (if yes, NinePatchRect with patch_margin_* needed)?
