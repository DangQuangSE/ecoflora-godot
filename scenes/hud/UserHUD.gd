class_name UserHUD
extends Control

const UserProfileCardScene := preload("res://scenes/hud/UserProfileCard.tscn")

@onready var _avatar: Control      = $AvatarRect
@onready var _name_label: Label    = $NameLabel
@onready var _level_label: Label   = $LevelLabel
@onready var _xp_bar: ProgressBar  = $XPBar
@onready var _coin_label: Label    = $CoinLabel

var _is_animating_level_up: bool = false
var _pending_levelup_max: int = 0
var _profile_card: CanvasLayer = null

func _ready() -> void:
	UserManager.xp_gained.connect(_on_xp_gained)
	UserManager.level_up.connect(_on_level_up)
	UserManager.currency_changed.connect(_on_currency_changed)
	var coin_path := "res://assets/icon/coin.png"
	if ResourceLoader.exists(coin_path):
		var coin_icon := get_node_or_null("CoinIcon") as TextureRect
		if coin_icon:
			coin_icon.texture = load(coin_path)
	_refresh()

func _exit_tree() -> void:
	UserManager.xp_gained.disconnect(_on_xp_gained)
	UserManager.level_up.disconnect(_on_level_up)
	UserManager.currency_changed.disconnect(_on_currency_changed)

func _refresh() -> void:
	var p := UserManager.get_profile()
	if p.username == "":
		return
	_name_label.text  = p.username
	_level_label.text = "%d" % p.level
	_xp_bar.max_value = p.xp_to_next_level()
	_xp_bar.value     = p.current_xp
	_coin_label.text  = str(p.currency)

func _on_xp_gained(_amount: int) -> void:
	_refresh()

func _on_currency_changed(new_amount: int) -> void:
	_coin_label.text = str(new_amount)

func _on_level_up(new_level: int) -> void:
	_refresh()
	_pending_levelup_max = max(_pending_levelup_max, new_level)
	if not _is_animating_level_up:
		_flush_levelup_anim()

func _flush_levelup_anim() -> void:
	if _pending_levelup_max == 0:
		return
	var lvl := _pending_levelup_max
	_pending_levelup_max = 0
	_play_level_up_anim(lvl)

func _play_level_up_anim(new_level: int) -> void:
	_is_animating_level_up = true
	var tween := create_tween()
	tween.tween_property(_avatar, "modulate", Color.WHITE, 0.1)
	tween.tween_property(_avatar, "modulate", Color(0.6, 0.4, 0.2, 1), 0.3)
	await tween.finished
	if not is_instance_valid(self):
		return
	_is_animating_level_up = false
	_spawn_levelup_label(new_level)
	_flush_levelup_anim()

func _spawn_levelup_label(new_level: int) -> void:
	var lbl := Label.new()
	lbl.text = "Level Up! Lv.%d" % new_level
	lbl.position = Vector2(0, -10)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.3, 1))
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(lbl)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 50.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.3)
	await tw.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

func _gui_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
				   or (event is InputEventScreenTouch and event.pressed)
	if not is_tap:
		return
	get_viewport().set_input_as_handled()
	_open_profile_card()

func _open_profile_card() -> void:
	if _profile_card != null and is_instance_valid(_profile_card):
		_profile_card.call("open")
		return
	_profile_card = UserProfileCardScene.instantiate()
	get_tree().root.add_child(_profile_card)
	_profile_card.call("open")
