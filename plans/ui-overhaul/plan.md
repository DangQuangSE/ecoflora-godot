# Plan: PNG Asset Integration — UI Overhaul
Status: Draft
Date: 2026-06-04
Mode: Fast

## Overview
Replace all StyleBoxFlat placeholder visuals in four scenes (Portal, UserHUD, ShopScene, ShopItemCard) with the design-team PNG assets. Zero GDScript or logic changes — pure .tscn texture wiring in the `scenes/` layer only.

## Phases
- [ ] Phase 1: Portal — Swap demo_portal.png → portal.png on Sprite2D ext_resource
- [ ] Phase 2: UserHUD Profile — Wire pf_frame.PNG, pf_name.PNG, pf_exp.PNG into HUD nodes
- [ ] Phase 3: Shop Scene — Add fullscreen BgTexture and StyleBoxTexture tab overrides
- [ ] Phase 4: Shop Item Card — Replace StyleBoxFlat_card with StyleBoxTexture(shop_card.png)

## Research Summary
N/A

## Dependencies
- All PNG assets confirmed present under `assets/` (verified via glob)
- `.import` sidecar files will auto-generate on first Godot open — no manual import step needed
- UserHUD.gd line 6: `@onready var _avatar: ColorRect = $AvatarRect` — type annotation must be updated to `TextureRect` when AvatarRect node type changes (Phase 2)

## Risks
- MEDIUM: AvatarRect type change (ColorRect → TextureRect) breaks the `@onready` type hint in UserHUD.gd — mitigation: update the annotation on line 6 alongside the .tscn edit; node name stays unchanged so path resolution is unaffected
- LOW: PNG filenames use mixed case (`.PNG` vs `.png`) on a case-sensitive filesystem — mitigation: use the exact casing shown in the asset list for all `res://` paths in .tscn
- LOW: shop_card.png without defined 9-patch margins may stretch unattractively on cards with varying content height — mitigation: set `StyleBoxTexture.draw_center = true` and leave margins at 0; revisit with NinePatchRect only if QA flags it
