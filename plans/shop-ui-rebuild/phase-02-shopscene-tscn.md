# Phase 2: ShopScene.tscn Rebuild

## Requirements
Rebuild ShopScene.tscn so the shop area uses shop_bg.png as a TextureRect background with four TextureButton tabs and a ScrollContainer/GridContainer for cards, completely removing the TabContainer. Existing Header, ConfirmOverlay, ConfirmDialog, ToastNotification, and LoadingSpinner nodes are preserved in place.

## Steps
1. Open ShopScene.tscn and delete the TabContainer node (and all its child tab pages); confirm no other nodes hold a direct reference to it before deletion.
2. Add a ShopPanel Control node (anchored y=72 to y=1280, full width) as the main shop content container.
3. Inside ShopPanel, add a ShopBg TextureRect, assign shop_bg.png, set stretch_mode to cover or keep_aspect_covered so the background fills the panel without distortion.
4. Inside ShopPanel, add a TabGroup HBoxContainer with four TextureButton children: TieuHaoBtn, HatGiongBtn, TrangTriBtn, NapCoinBtn. Assign shop_tab.png as the normal texture and shop_tab_clicked.png as the pressed texture on all four buttons.
5. Inside ShopPanel, add a ScrollContainer and nest a GridContainer (columns=3) inside it. Set ScrollContainer bounds to cover the card area visible in shop_bg.png; set GridContainer size flags to expand horizontally so cards fill available columns.
6. Verify Header (BackButton, TitleRow, CurrencyBox), ConfirmOverlay, ConfirmDialog, ToastNotification, and LoadingSpinner remain as siblings to ShopPanel and are not accidentally reparented or deleted.
7. Manually tune TabGroup position and ScrollContainer bounds in the Godot editor viewport against shop_bg.png to align with the art — pixel values cannot be finalized without visual inspection; mark positions as "needs editor tuning" in node comments if exact values are uncertain.

## Success Criteria
- TabContainer is fully removed; no orphaned tab-page nodes remain in the scene tree
- ShopBg displays shop_bg.png filling ShopPanel without aspect distortion
- All four TextureButtons show shop_tab.png in their normal state and shop_tab_clicked.png when pressed in editor preview
- GridContainer has columns property set to 3
- Header, ConfirmDialog, ToastNotification, and LoadingSpinner still exist in the scene tree and are selectable in the editor
- Scene opens without errors in the Godot editor

## Risks
- TabGroup and ScrollContainer pixel positions depend on shop_bg.png visual layout: exact anchor/offset values must be set manually in editor after implementing the node structure — mitigate by using placeholder positions initially and scheduling a visual tuning pass
- Accidental deletion of Header or overlay nodes during TabContainer removal: mitigate by collapsing those branches in the scene tree editor before starting the deletion
