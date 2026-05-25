class_name DynamicJoystick
extends Control

signal direction_changed(direction: Vector2)

const HOLD_DURATION := 1.0
const MAX_RADIUS    := 60.0
const ZONE_Y_RATIO  := 0.6

@onready var _background: Control = $Background
@onready var _knob: Control       = $Background/Knob

var _touch_index: int  = -1
var _hold_timer: float = 0.0
var _origin: Vector2   = Vector2.ZERO
var _active: bool      = false

func _ready() -> void:
	_background.visible = false
	mouse_filter = MOUSE_FILTER_IGNORE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		if event.index == _touch_index and _active:
			_handle_drag(event)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _touch_index >= 0 and not _active:
		_hold_timer += delta
		if _hold_timer >= HOLD_DURATION:
			_show_joystick()

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		var zone_y: float = get_viewport().get_visible_rect().size.y * ZONE_Y_RATIO
		if event.position.y < zone_y:
			return
		_touch_index = event.index
		_origin      = event.position
		_hold_timer  = 0.0
		get_viewport().set_input_as_handled()
	elif event.index == _touch_index:
		_reset()

func _show_joystick() -> void:
	_active = true
	_background.global_position = _origin - _background.size / 2.0
	_background.visible = true

func _handle_drag(event: InputEventScreenDrag) -> void:
	var offset: Vector2  = event.position - _origin
	var clamped: Vector2 = offset.limit_length(MAX_RADIUS)
	_knob.position = clamped
	direction_changed.emit(clamped / MAX_RADIUS)

func _reset() -> void:
	_touch_index = -1
	_hold_timer  = 0.0
	_active      = false
	_background.visible = false
	_knob.position      = Vector2.ZERO
	direction_changed.emit(Vector2.ZERO)
