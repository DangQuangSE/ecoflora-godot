# Phase 04 — CharacterSelectScene (forced post-register)

**Goal:** New full-screen scene shown once after `register_succeeded`. Displays all characters: owned selectable, locked previews only. Saves selection locally. Fades to LoginScene — no BE call (no token yet).

**Covers:** FR-01 | **Dependencies:** Phase 2 (SpriteFrames assets must exist)

---

## Files

| File | Change |
|------|--------|
| `scenes/auth/CharacterSelectScene.tscn` | New |
| `scenes/auth/CharacterSelectScene.gd` | New |
| `scenes/auth/RegisterScene.gd` | Change `on_register_success()` destination |

---

## CharacterSelectScene layout (portrait 390×844)

```
CharacterSelectScene (Node2D or CanvasLayer)
  Background (ColorRect — full screen, dark green)
  Title (Label — "Chọn Nhân Vật", centered top)
  CharacterGrid (HBoxContainer — centered middle)
    CharCard0 (Panel)
      Preview (AnimatedSprite2D)
      NameLabel (Label — "Mặc định")
      StatusLabel (Label — "Miễn phí")
      SelectedBorder (Panel — visible when selected)
    CharCard1 (Panel)
      Preview (AnimatedSprite2D)
      NameLabel (Label — "Nhân vật 1")
      StatusLabel (Label — "10,000 coin")
      LockOverlay (Panel — semi-transparent, visible = true by default)
  ConfirmBtn (Button — "Bắt đầu")
```

`LockOverlay` greys out the card and blocks input for unowned characters.

---

## CharacterSelectScene.gd

```gdscript
extends Node

const LOGIN_SCENE := "res://scenes/auth/LoginScene.tscn"
const _CHARACTER_FRAMES: Array = [
	preload("res://assets/characters/char_0.tres"),
	preload("res://assets/characters/char_1.tres"),
]
const _CHARACTER_NAMES := ["Mặc định", "Nhân vật 1"]
const _OWNED_AT_REGISTER: Array[int] = [0]  # new users own only char 0

@onready var _confirm_btn: Button = $ConfirmBtn
@onready var _grid: HBoxContainer = $CharacterGrid

var _selected_idx: int = 0

func _ready() -> void:
	_build_cards()
	_confirm_btn.pressed.connect(_on_confirm)
	_select(0)

func _build_cards() -> void:
	for i in _CHARACTER_FRAMES.size():
		var card := _grid.get_child(i) as Panel
		if not card:
			continue
		var preview := card.get_node("Preview") as AnimatedSprite2D
		preview.sprite_frames = _CHARACTER_FRAMES[i]
		preview.play("idle_down")
		(card.get_node("NameLabel") as Label).text = _CHARACTER_NAMES[i]
		var owned: bool = i in _OWNED_AT_REGISTER
		var lock := card.get_node_or_null("LockOverlay") as Panel
		if lock:
			lock.visible = not owned
		if owned:
			card.gui_input.connect(_on_card_input.bind(i))

func _on_card_input(event: InputEvent, idx: int) -> void:
	if (event is InputEventMouseButton and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		_select(idx)

func _select(idx: int) -> void:
	if not (idx in _OWNED_AT_REGISTER):
		return
	_selected_idx = idx
	for i in _CHARACTER_FRAMES.size():
		var card := _grid.get_child(i) as Panel
		if card:
			var border := card.get_node_or_null("SelectedBorder") as Panel
			if border:
				border.visible = (i == idx)

func _on_confirm() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("character", "index", _selected_idx)
	cfg.set_value("character", "owned", JSON.stringify(Array(_OWNED_AT_REGISTER)))
	cfg.save("user://character_prefs.cfg")
	SceneTransition.fade_to(LOGIN_SCENE)
```

---

## RegisterScene.gd change

Add constant and update `on_register_success()`:

```gdscript
# Add near the top:
const CHARACTER_SELECT_SCENE := "res://scenes/auth/CharacterSelectScene.tscn"

# Change (around line 120):
func on_register_success() -> void:
	SceneTransition.fade_to(CHARACTER_SELECT_SCENE)
```

Check if `LOGIN_SCENE` is still referenced in RegisterScene; if not, remove it.

---

## Acceptance Check

- Register completes → CharacterSelectScene appears (not LoginScene directly)
- Char 0 card: selectable, SelectedBorder visible on tap, no LockOverlay
- Char 1 card: LockOverlay visible, tapping does NOT change selection
- ConfirmBtn always enabled — tapping saves `index=0` to `character_prefs.cfg`, fades to LoginScene
- No Back button or swipe-dismiss — user cannot skip
- `character_prefs.cfg` contains `index = 0` and `owned = "[0]"` after confirm
