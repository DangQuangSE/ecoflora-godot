# Plan: Shop UI Rebuild
Status: ðŸŸ¡ In Progress
Date: 2026-06-06
Mode: Fast

## Overview
Rebuild ShopScene entirely using PNG assets (shop_bg, shop_tab, shop_card) instead of Godot's default TabContainer and StyleBox nodes. Delivers a fully data-driven, visually custom shop with TextureButton tabs and NinePatchRect cards driven by mock data.

## Phases
- [x] Phase 1: ShopItemCard Rebuild â€” replace StyleBoxFlat PanelContainer background with NinePatchRect using shop_card.png; update node path references in script if needed
- [x] Phase 2: ShopScene.tscn Rebuild â€” remove TabContainer; construct ShopPanel with ShopBg TextureRect, TabGroup HBoxContainer with 4 TextureButtons, ScrollContainer + GridContainer(columns=3); preserve Header and overlay nodes
- [x] Phase 3: ShopScene.gd Rewrite â€” replace TabContainer logic with TextureButton tab array and _MOCK data constant; implement _on_tab_pressed, _set_active_tab, _render_items; keep existing confirm/toast/back handlers

## Research Summary
N/A

## Dependencies
- Assets confirmed present: res://assets/shop/shop_bg.png, shop_tab.png, shop_tab_clicked.png, shop_card.png
- Icon assets for mock data: res://assets/icon/watering_can.png, fertilizer.png, sickle.png (used in mock â€” missing icons render without texture, not a blocker)
- UserManager autoload must be available at runtime (already registered)
- ShopItem domain class and ShopItemCard.setup() contract must remain stable across phases

## Risks
- MEDIUM: TabGroup and ScrollContainer pixel positions depend on shop_bg.png visual layout â€” exact anchor/offset values cannot be determined without opening the image in editor; mitigation: note in phase 2 that positions require manual tuning in Godot editor after initial placement
- MEDIUM: NinePatchRect patch_margin values for shop_card.png are unknown until tested in editor â€” incorrect margins will stretch or tile the card art; mitigation: set conservative equal margins initially and adjust visually
- LOW: Icon assets referenced in _MOCK (watering_can.png, fertilizer.png, sickle.png) may be missing or have different paths â€” mitigation: empty icon_path falls back gracefully if ShopItemCard.setup() guards against null texture

## Session Notes
**Last active:** 2026-06-06
**Status:** All 3 phases complete

### Decisions made this session
- ShopItemCard root: PanelContainer -> Control, NinePatchRect CardBg patch_margin=20 (tune in editor)
- TabGroup offset_top=0, ScrollContainer offset_top=200 (approximate, tune after seeing shop_bg.png)
- _render_items: queue_free + synchronous add_child; empty tab placeholder uses call_deferred
- _MOCK int keys 0-3, preload tab textures as const

### Next immediate action
Open Godot editor, tune TabGroup and ScrollContainer positions to match shop_bg.png visual layout
