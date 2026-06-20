extends Node2D

const FocusTimerUIScene := preload("res://scenes/school/FocusTimerUI.tscn")

@onready var _player: Player   = $Player
@onready var _hud             = $HUD
@onready var _focus_btn: Button = $FocusLayer/FocusButton

var _timer_ui: CanvasLayer = null
var _boundary_rect: Rect2 = Rect2()

func _ready() -> void:
	_connect_hud_joystick()
	_boundary_rect = _compute_boundary()
	_player.setup_camera_world_limits(_boundary_rect)
	_player.set_movement_bounds(_boundary_rect)
	_focus_btn.pressed.connect(_on_focus_btn_pressed)
	FocusManager.session_completed.connect(func(_m: int) -> void: _on_session_ended())
	FocusManager.session_failed.connect(_on_session_ended)
	FocusManager.session_cancelled.connect(_on_session_ended)
	SceneTransition.apply_spawn_origin(self, _player)
	_focus_btn.disabled = FocusManager.get_state() == FocusManager.State.ACTIVE

func _connect_hud_joystick() -> void:
	if _hud.has_signal("joystick_direction_changed"):
		_hud.connect("joystick_direction_changed", _player.set_move_direction)
		return
	var joystick := _hud.get_node_or_null("DynamicJoystick")
	if joystick != null and joystick.has_signal("direction_changed"):
		joystick.connect("direction_changed", _player.set_move_direction)

func _compute_boundary() -> Rect2:
	var bg := get_node_or_null("ClassBg") as Sprite2D
	if bg == null or bg.texture == null:
		return Rect2()
	var tex_size := Vector2(bg.texture.get_width(), bg.texture.get_height())
	if bg.region_enabled:
		tex_size = bg.region_rect.size
	var world_size := tex_size * bg.scale
	if bg.centered:
		return Rect2(bg.global_position - world_size / 2.0, world_size)
	return Rect2(bg.global_position, world_size)

func _on_focus_btn_pressed() -> void:
	if _timer_ui != null and is_instance_valid(_timer_ui):
		return
	_timer_ui = FocusTimerUIScene.instantiate()
	_timer_ui.tree_exited.connect(_on_timer_ui_closed)
	add_child(_timer_ui)
	_focus_btn.disabled = true

func _on_session_ended() -> void:
	_focus_btn.disabled = false

func _on_timer_ui_closed() -> void:
	if FocusManager.get_state() != FocusManager.State.ACTIVE:
		_focus_btn.disabled = false

func _exit_tree() -> void:
	FocusManager.cancel_session()
