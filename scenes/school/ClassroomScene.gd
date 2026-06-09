extends Node2D

const FocusTimerUIScene := preload("res://scenes/school/FocusTimerUI.tscn")

@onready var _player: Player   = $Player
@onready var _hud: HUD         = $HUD
@onready var _focus_btn: Button = $FocusLayer/FocusButton

var _timer_ui: CanvasLayer = null

func _ready() -> void:
	_hud.joystick_direction_changed.connect(_player.set_move_direction)
	_player.setup_camera_limits(Rect2i(), Vector2i(16, 16))
	_focus_btn.pressed.connect(_on_focus_btn_pressed)
	FocusManager.session_completed.connect(_on_session_ended)
	FocusManager.session_failed.connect(_on_session_ended)
	FocusManager.session_cancelled.connect(_on_session_ended)
	SceneTransition.apply_spawn_origin(self, _player)
	_focus_btn.disabled = FocusManager.get_state() == FocusManager.State.ACTIVE

func _on_focus_btn_pressed() -> void:
	if _timer_ui != null and is_instance_valid(_timer_ui):
		return
	_timer_ui = FocusTimerUIScene.instantiate()
	add_child(_timer_ui)
	_focus_btn.disabled = true

func _on_session_ended() -> void:
	_focus_btn.disabled = false

func _exit_tree() -> void:
	FocusManager.cancel_session()
