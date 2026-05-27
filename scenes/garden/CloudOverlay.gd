class_name CloudOverlay
extends Node2D

@export var zone_texture: Texture2D

@onready var _rect: ColorRect = $ColorRect

var _zone_id: String = ""
var _tappable: bool = false
var _pulse_tween: Tween = null

func setup(zone_id: String) -> void:
	_zone_id = zone_id

func _ready() -> void:
	_rect.gui_input.connect(_on_rect_gui_input)
	ZoneManager.zone_notification.connect(_on_notified)
	ZoneManager.zone_unlocked.connect(_on_unlocked)
	var state := ZoneManager.get_zone_state(_zone_id)
	if state == ZoneManager.ZoneState.NOTIFIED:
		_on_notified(_zone_id)
	elif state == ZoneManager.ZoneState.UNLOCKED:
		queue_free()

func _on_notified(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = true
	_start_pulse()

func _start_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_rect, "modulate:a", 0.55, 0.5)
	_pulse_tween.tween_property(_rect, "modulate:a", 1.0, 0.5)

func _on_unlocked(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = false
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	if ZoneManager.zone_notification.is_connected(_on_notified):
		ZoneManager.zone_notification.disconnect(_on_notified)
	if ZoneManager.zone_unlocked.is_connected(_on_unlocked):
		ZoneManager.zone_unlocked.disconnect(_on_unlocked)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

func _on_rect_gui_input(event: InputEvent) -> void:
	if not _tappable:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		get_viewport().set_input_as_handled()
		ZoneManager.request_unlock(_zone_id)
