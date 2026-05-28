extends Node2D

const FocusTimerUIScene := preload("res://scenes/school/FocusTimerUI.tscn")

@onready var _player: Player  = $Player
@onready var _hud: HUD        = $HUD
@onready var _trigger: Area2D = $ClassroomTrigger

var _timer_ui: CanvasLayer = null

func _ready() -> void:
	_hud.joystick_direction_changed.connect(_player.set_move_direction)
	_player.setup_camera_limits(Rect2i(), Vector2i(16, 16))
	_trigger.body_entered.connect(_on_trigger_body_entered)

func _on_trigger_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	if _timer_ui != null and is_instance_valid(_timer_ui):
		return
	_timer_ui = FocusTimerUIScene.instantiate()
	add_child(_timer_ui)

func _exit_tree() -> void:
	FocusManager.cancel_session()
