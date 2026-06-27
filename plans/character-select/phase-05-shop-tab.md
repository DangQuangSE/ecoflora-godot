# Phase 05 — Shop "Nhân Vật" Tab

**Goal:** Insert Character tab at index 2, hardcoded catalog, "Đã sở hữu" / price display, purchase flow extending `purchase_async`.

**Covers:** FR-06 | **Dependencies:** Phase 1 (BE purchase endpoint), Phase 3 (UserManager owned state)

---

## Files

| File | Change |
|------|--------|
| `scenes/shop/ShopScene.gd` | Insert tab, add catalog const, render+purchase logic |
| `scenes/shop/ShopScene.tscn` | Add NhanVatBtn node at tab index 2 |

---

## ShopScene.gd changes

**1. `_TAB_CATEGORIES`** (line 12) — insert at index 2:
```gdscript
# Before:
const _TAB_CATEGORIES := ["Seed", "Consumable", "Decoration", "Coin"]
# After:
const _TAB_CATEGORIES := ["Seed", "Consumable", "Character", "Decoration", "Coin"]
```

**2. Character catalog** — add after `_COIN_PACKAGES`:
```gdscript
const _CHARACTER_CATALOG := [
	{"id": "character:0", "name": "Mặc định", "price": 0,     "preview": "res://assets/characters/char_0_thumb.png"},
	{"id": "character:1", "name": "Nhân vật 1", "price": 10000, "preview": "res://assets/characters/char_1_thumb.png"},
]
```

**3. Tab buttons array** — `_tab_btns` is built from `_TAB_CATEGORIES` length; add `NhanVatBtn` node to the `.tscn` at position 2 in the tab group (between CongCuBtn and TrangTriBtn). The array build loop at lines 76–80 is index-based, so adding the node is sufficient.

**4. `_render_items()`** — add Character branch (before Coin branch):
```gdscript
"Character":
	_build_character_items()
```

**5. New method `_build_character_items()`:**
```gdscript
func _build_character_items() -> void:
	_item_list.clear()
	for entry in _CHARACTER_CATALOG:
		var owned: bool = UserManager.is_character_owned(
			int(entry["id"].split(":")[1])
		)
		_item_list.add_item({
			"id": entry["id"],
			"name": entry["name"],
			"category": "Character",
			"price": entry["price"],
			"quantity": -1,
			"preview_path": entry["preview"],
			"owned": owned,
		})
```

**6. Item card rendering** — in `_render_items()` or the card builder, when `item.category == "Character"`:
- If `item.owned`: show label "Đã sở hữu", disable buy button
- Else: show price, enable buy button
- Never show an equip button

**7. `_on_confirm_purchase()`** — after `await UserManager.purchase_async(...)`:
```gdscript
if _selected_item.get("category") == "Character":
	_refresh_tab()   # rebuild character cards with updated owned state
	return           # skip InventoryManager.refresh_async
```

---

## ShopScene.tscn changes

In the tab button group (child of `ShopBg` or `TabGroup`), add a new Button node `NhanVatBtn` between `CongCuBtn` (index 1) and `TrangTriBtn` (now index 3). Match existing tab button styling. Label: `"Nhân Vật"`.

---

## Acceptance Check

- Shop opens to Seed tab by default (index 0 unchanged)
- Tapping "Nhân Vật" tab shows 2 character cards
- Character 0 always shows "Đã sở hữu"
- Character 1 shows "10,000" price and Buy button for new players
- Purchase deducts 10,000 coin; card immediately updates to "Đã sở hữu"
- Decoration tab still works at new index 3; Coin tab at index 4
- No equip button appears anywhere in ShopScene
