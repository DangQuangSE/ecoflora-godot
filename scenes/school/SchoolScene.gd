extends Node2D

@onready var _player: Player = $Player
@onready var _hud: HUD       = $HUD

func _ready() -> void:
	_hud.joystick_direction_changed.connect(_player.set_move_direction)
	_player.setup_camera_limits(Rect2i(), Vector2i(16, 16))
