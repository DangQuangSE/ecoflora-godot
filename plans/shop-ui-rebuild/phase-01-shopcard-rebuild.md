# Phase 1: ShopItemCard Rebuild

## Requirements
Replace the StyleBoxFlat PanelContainer background in ShopItemCard.tscn with a NinePatchRect node using shop_card.png, so each card in the grid displays the custom card art as its background. Script logic and public API (setup, tapped signal, set_affordable) remain unchanged.

## Steps
1. Open ShopItemCard.tscn and identify the root PanelContainer node and any StyleBoxFlat theme override that provides the current background.
2. Replace the root or background node with a NinePatchRect, assign shop_card.png as its texture, and set patch_margin values to match the card art's nine-patch borders (start conservatively at equal margins, tune visually in editor).
3. Ensure all child nodes (icon, name label, price label, buy button) remain correctly nested inside or on top of the NinePatchRect so existing layout is preserved.
4. Open ShopItemCard.gd and update any node path references (e.g. $PanelContainer/...) that broke due to the root node rename; confirm setup(), set_affordable(), and the tapped signal connection still resolve correctly.
5. Run a quick in-editor test by instantiating one ShopItemCard in a temporary scene or directly in ShopScene to confirm shop_card.png renders as the card background without stretching.

## Success Criteria
- shop_card.png is visible as the background of every ShopItemCard instance in the grid
- Card art does not stretch or tile incorrectly (nine-patch borders are visually clean)
- setup() populates name, price, and icon without errors
- tapped signal fires when the card is pressed
- No GDScript errors reported by the editor on ShopItemCard.gd

## Risks
- NinePatchRect patch_margin mismatch: the art borders may not align with default margin values — mitigate by tuning margins in editor before moving to phase 2
- Node path breakage in ShopItemCard.gd if the root container name changes — mitigate by checking all $ references and @onready vars in the script immediately after renaming the node
