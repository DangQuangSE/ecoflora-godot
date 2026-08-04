class_name WeatherNpcBubble
extends CanvasLayer

signal dismissed

@export var auto_hide_seconds: float = 60
@export var fade_duration: float = 0.6
# offset from vertical screen center
@export var vertical_offset: float = 10.0
# distance from the right edge of the screen (bubble spans -110..110 around this point)
@export var horizontal_offset: float = 130.0

@onready var _position_root: Control = $PositionRoot
@onready var _npc_button: TextureButton = $PositionRoot/NpcButton
@onready var _message_label: Label = $PositionRoot/BubblePanel/MessageLabel

var _active_tween: Tween = null


func _ready() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_position_root.position = Vector2(viewport_size.x - horizontal_offset, viewport_size.y / 2.0 + vertical_offset)
	_npc_button.pressed.connect(_on_button_pressed)
	tree_exiting.connect(_on_tree_exiting)


func show_message(msg: String) -> void:
	_message_label.text = msg
	_position_root.modulate.a = 1.0
	await get_tree().create_timer(auto_hide_seconds).timeout
	if not is_instance_valid(self):
		return
	_active_tween = create_tween()
	_active_tween.tween_property(_position_root, "modulate:a", 0.0, fade_duration)
	await _active_tween.finished
	if is_instance_valid(self):
		dismissed.emit()
		queue_free()


func _on_button_pressed() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	dismissed.emit()
	queue_free()


func _on_tree_exiting() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
