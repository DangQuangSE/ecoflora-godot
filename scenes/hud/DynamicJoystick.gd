class_name DynamicJoystick
extends Control

signal direction_changed(direction: Vector2)

const MAX_RADIUS   := 55.0
const ZONE_Y_RATIO := 0.55

@onready var _background: Control = $Background
@onready var _knob: Control       = $Background/Knob

var _touch_index: int = -1
var _origin: Vector2  = Vector2.ZERO
var _active: bool     = false

func _ready() -> void:
	_background.visible = false
	mouse_filter = MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_try_start(event.position, event.index)
		elif event.index == _touch_index:
			_reset()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index and _active:
			_move_knob(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start(event.position, 0)
		else:
			_reset()
	elif event is InputEventMouseMotion and _active:
		_move_knob(event.position)

func _try_start(pos: Vector2, index: int) -> void:
	if InventoryManager.get_selected_item() != null:
		return
	var zone_y := get_viewport().get_visible_rect().size.y * ZONE_Y_RATIO
	if pos.y < zone_y:
		return
	_touch_index = index
	_origin      = pos
	_active      = true
	_background.global_position = _origin - _background.size / 2.0
	_background.visible = true

func _move_knob(pos: Vector2) -> void:
	var offset  := pos - _origin
	var clamped := offset.limit_length(MAX_RADIUS)
	_knob.position = _background.size / 2.0 - _knob.size / 2.0 + clamped
	direction_changed.emit(clamped / MAX_RADIUS)

func _reset() -> void:
	_touch_index        = -1
	_active             = false
	_background.visible = false
	_knob.position      = _background.size / 2.0 - _knob.size / 2.0
	direction_changed.emit(Vector2.ZERO)
