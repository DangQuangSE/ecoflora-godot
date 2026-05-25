class_name HUD
extends CanvasLayer

signal joystick_direction_changed(direction: Vector2)

@onready var _joystick: DynamicJoystick = $DynamicJoystick

func _ready() -> void:
	_joystick.direction_changed.connect(_on_joystick_direction)

func _on_joystick_direction(dir: Vector2) -> void:
	joystick_direction_changed.emit(dir)
