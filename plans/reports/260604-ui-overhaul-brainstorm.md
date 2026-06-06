# Brainstorm: UI Asset Integration Overhaul

**Date:** 2026-06-04

## Ideas Explored

- **Full rebuild approach** — rewrite .tscn layout from scratch to match a design system. Dismissed: no mockup reference, high risk of breaking signal paths.
- **StyleBoxTexture swap** — replace StyleBoxFlat with StyleBoxTexture using PNG assets. Simple, preserves all node names/paths. Best fit for non-mockup scenario.
- **NinePatchRect containers** — wrap card content in NinePatchRect for proper PNG stretching. Preferred over StyleBoxTexture for shop_card.png if PNG has corners.
- **Custom tab buttons** — replace TabContainer with HBoxContainer + Buttons for shop tabs. Dismissed: requires rewriting tab switching logic in ShopScene.gd.
- **TabContainer StyleBoxTexture tabs** — apply shop_tab.png / shop_tab_clicked.png via theme override on TabContainer. Keeps existing code, no logic changes.

## User's Direction

Replace all StyleBoxFlat placeholder visuals with PNG assets provided by design team. Keep node structure and signal wiring intact. No mockup — infer layout from asset names and game context.

Scenes in scope:
1. Portal.tscn — swap demo_portal.png → portal.png
2. UserHUD.tscn — use pf_frame.PNG (avatar), pf_name.PNG (name strip), pf_exp.PNG (xp bar bg)
3. ShopScene.tscn — shop_bg.PNG background, shop_tab.png / shop_tab_clicked.png for tabs
4. ShopItemCard.tscn — shop_card.png as card background (NinePatchRect or StyleBoxTexture)

UserProfileCard.tscn, VitalityBar.tscn, InventoryPanel.tscn — no new assets for these; leave as-is.

## Open Questions

- shop_card.png / pf_exp.PNG / pf_name.PNG / pf_frame.PNG: do they have defined 9-patch margins? (affects stretch quality — /ck:plan must decide NinePatchRect margins or StyleBoxTexture texture_margin)
- shop_bg.PNG aspect ratio vs 720×1280 portrait screen — does it fill edge-to-edge or have padding?
- pf_frame.PNG: is it a border ring (overlay) or a filled background?

## Risks

1. PNG dimensions unknown — wrong stretch mode on TextureRect causes pixelation or squishing on mobile
2. TabContainer StyleBoxTexture tab height may clip PNG if tab panel height is hardcoded
3. AvatarRect is ColorRect (not Panel) — replacing with TextureRect changes node type, any GDScript ref to `$AvatarRect` in UserHUD.gd must be updated if it uses ColorRect-specific methods
