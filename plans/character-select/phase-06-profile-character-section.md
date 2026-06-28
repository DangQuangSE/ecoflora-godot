# Phase 06 — Profile Character Section (Equip)

**Goal:** Add character picker section to `UserProfileCard`. Lists owned characters with "Đang mặc" badge. Tap equips via `UserManager.set_character_async()`.

**Covers:** FR-07 (equip), FR-08 | **Dependencies:** Phase 3 (UserManager), Phase 2 (sprite swap)

---

## Files

| File | Change |
|------|--------|
| `scenes/hud/UserProfileCard.gd` | Add character picker logic + signal listener |
| `scenes/hud/UserProfileCard.tscn` | Add `CharacterPicker` VBoxContainer node |

---

## .tscn additions

Under `$Card/Content` (after stats rows), add:

```
CharacterSection (VBoxContainer)
  SectionTitle (Label — "Nhân Vật")
  CharacterGrid (HBoxContainer)
    CharBtn0 (Button)   ← child nodes: Tex (TextureRect), EquippedBadge (Label — "Đang mặc")
    CharBtn1 (Button)
```

`CharBtn*` nodes: same dimensions as avatar picker buttons. `EquippedBadge` hidden by default.

---

## UserProfileCard.gd additions

**1. `@onready` vars:**
```gdscript
@onready var _char_section: VBoxContainer = $Card/Content/CharacterSection
@onready var _char_grid: HBoxContainer    = $Card/Content/CharacterSection/CharacterGrid
```

**2. Character thumbnails constant:**
```gdscript
const _CHAR_THUMBS := [
	"res://assets/characters/char_0_thumb.png",
	"res://assets/characters/char_1_thumb.png",
]
```

**3. In `_ready()`** — after existing setup:
```gdscript
_load_char_buttons()
UserManager.character_changed.connect(_refresh_character_section)
```

**4. `_load_char_buttons()`:**
```gdscript
func _load_char_buttons() -> void:
	for i in _CHAR_THUMBS.size():
		var btn := _char_grid.get_child(i) as Button
		if not btn:
			continue
		var tex := btn.get_node_or_null("Tex") as TextureRect
		if tex and ResourceLoader.exists(_CHAR_THUMBS[i]):
			tex.texture = load(_CHAR_THUMBS[i])
		btn.pressed.connect(_on_char_selected.bind(i))
```

**5. `_refresh_character_section()`:**
```gdscript
func _refresh_character_section(_idx: int = -1) -> void:
	var owned := UserManager.get_owned_characters()
	var equipped := UserManager.get_character_index()
	for i in _CHAR_THUMBS.size():
		var btn := _char_grid.get_child(i) as Button
		if not btn:
			continue
		btn.visible = (i in owned)
		var badge := btn.get_node_or_null("EquippedBadge") as Label
		if badge:
			badge.visible = (i == equipped)
```

**6. `_on_char_selected(idx: int)`:**
```gdscript
func _on_char_selected(idx: int) -> void:
	if UserManager.is_character_owned(idx):
		UserManager.set_character_async(idx)
```

**7. Extend `_refresh_data()`** — add at end:
```gdscript
_refresh_character_section()
```

**8. `_exit_tree()`** — disconnect:
```gdscript
if UserManager.character_changed.is_connected(_refresh_character_section):
	UserManager.character_changed.disconnect(_refresh_character_section)
```

---

## Acceptance Check

- Profile opens → CharacterSection shows only owned characters
- Equipped character has "Đang mặc" badge visible
- Tapping an owned (non-equipped) character → badge moves, `character_changed` signal fires
- Unowned character cards are hidden (not shown as locked/greyed)
- After `set_character_async()` rollback, badge reverts to previous character
- `_exit_tree` disconnects cleanly (no orphan signal connections)
