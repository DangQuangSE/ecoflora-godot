# Phase 3: ShopScene.gd Rewrite

## Requirements
Rewrite ShopScene.gd to drive the new TextureButton tabs and GridContainer using a local _MOCK data constant, replacing all TabContainer-based logic while keeping the existing back, confirm-purchase, and toast handlers untouched.

## Steps
1. Remove all TabContainer @onready references and any signal connections to tab_changed; add @onready references for the four TextureButton tab nodes (TieuHaoBtn, HatGiongBtn, TrangTriBtn, NapCoinBtn), the GridContainer, and the ScrollContainer.
2. Declare the _MOCK Dictionary constant with the four tab entries (indices 0–3) as specified in the spec, each containing an Array of Dictionaries with keys id, name, price, icon_path.
3. In _ready(), connect each TextureButton's pressed signal to _on_tab_pressed with its index (0–3) using a lambda or bind, then call _on_tab_pressed(0) to show the first tab by default.
4. Implement _set_active_tab(idx: int) to iterate the tab button array and swap each button's texture_normal between shop_tab.png and shop_tab_clicked.png based on whether its index matches idx.
5. Implement _render_items(items: Array) to queue_free all current GridContainer children, then for each Dictionary in items instantiate ShopItemCard, call setup() with a ShopItem built from the dictionary and the current UserManager balance, add it to the grid, and connect its tapped signal to _on_item_tapped.
6. Implement _on_tab_pressed(idx: int) to call _set_active_tab(idx) then _render_items(_MOCK.get(idx, [])).
7. Confirm _on_item_tapped, _on_confirm_purchase, _show_toast, and the back button handler are unchanged and still resolve their node references against the preserved Header and overlay nodes from phase 2.

## Success Criteria
- Pressing any tab clears the grid and populates it with the correct items from _MOCK within one frame
- The active tab displays shop_tab_clicked.png; all other tabs display shop_tab.png
- Cards instantiated in the grid have correct name, price, and icon as defined in _MOCK
- Pressing a card's buy action still triggers the ConfirmDialog flow
- Confirming a purchase still calls the existing purchase handler and shows the toast
- Back button still navigates away from ShopScene
- No GDScript static analysis errors (godot --check-only passes)

## Risks
- Icon paths in _MOCK for watering_can.png, fertilizer.png, sickle.png may not resolve at runtime if assets are at different paths: mitigate by guarding texture load in ShopItemCard.setup() with a null check and falling back to no texture
- _render_items calls queue_free synchronously before adding new children — if called in rapid succession (double-tap), stale freed nodes may still exist for one frame: mitigate by checking get_child_count after the free loop or deferring with call_deferred if flickering is observed during testing
