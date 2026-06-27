extends Control

const LOGIN_SCENE := "res://scenes/auth/LoginScene.tscn"

const _CHARACTER_FRAME_PATHS: Array[String] = [
	"res://assets/characters/char_0.tres",
	"res://assets/characters/char_1.tres",
]
const _CHARACTER_NAMES: Array[String] = ["Mặc định", "Nhân vật 1"]
const _OWNED_AT_REGISTER: Array[int] = [0]

@onready var _confirm_btn: Button = $ConfirmBtn
@onready var _grid: HBoxContainer = $CharacterGrid

var _selected_idx: int = 0

func _ready() -> void:
	_build_cards()
	_confirm_btn.pressed.connect(_on_confirm)
	_select(0)

func _build_cards() -> void:
	for i in _CHARACTER_FRAME_PATHS.size():
		var card := _grid.get_child(i) as Panel
		if not card:
			continue
		var preview := card.get_node("Preview") as AnimatedSprite2D
		if ResourceLoader.exists(_CHARACTER_FRAME_PATHS[i]):
			var frames: SpriteFrames = load(_CHARACTER_FRAME_PATHS[i])
			preview.sprite_frames = frames
			if frames.has_animation("idle_down"):
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
	for i in _CHARACTER_FRAME_PATHS.size():
		var card := _grid.get_child(i) as Panel
		if card:
			var border := card.get_node_or_null("SelectedBorder") as Panel
			if border:
				border.visible = (i == idx)

func _on_confirm() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("character", "index", _selected_idx)
	cfg.set_value("character", "owned", JSON.stringify(_OWNED_AT_REGISTER))
	cfg.save("user://character_prefs.cfg")
	SceneTransition.fade_to(LOGIN_SCENE)
