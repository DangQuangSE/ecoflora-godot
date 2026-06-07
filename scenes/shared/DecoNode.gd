class_name DecoNode
extends Sprite2D

signal tapped(placement_id: String)
signal drag_ended(placement_id: String, new_pos: Vector2)

var placement_data: DecoPlacement

var boundary_rect: Rect2 = Rect2()

var _area: Area2D
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_dragging: bool = false

const _DRAG_THRESHOLD: float = 12.0
const _TAP_MAX_SEC: float = 0.3
const _DISPLAY_PX: float = 100.0

func _ready() -> void:
	_area = $Area2D
	var shape_node := $Area2D/CollisionShape2D as CollisionShape2D
	if placement_data == null:
		push_warning("DecoNode: placement_data is null")
		return
	var tex := ItemIconRegistry.get_icon(placement_data.decor_slug)
	texture = tex
	if tex != null:
		var s := _DISPLAY_PX / maxf(tex.get_width(), tex.get_height())
		scale = Vector2(s, s)
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(_DISPLAY_PX, _DISPLAY_PX)
		shape_node.shape = rect_shape
	_area.input_event.connect(_on_area_input_event)

func _on_area_input_event(_vp: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_start_pos = touch.position
			_touch_start_time = Time.get_ticks_msec() / 1000.0
			_is_dragging = false
		else:
			var elapsed := Time.get_ticks_msec() / 1000.0 - _touch_start_time
			var dist := touch.position.distance_to(_touch_start_pos)
			if not DecoManager.edit_mode and dist < _DRAG_THRESHOLD and elapsed < _TAP_MAX_SEC:
				tapped.emit(placement_data.id)
				get_viewport().set_input_as_handled()
			elif _is_dragging and DecoManager.edit_mode:
				_is_dragging = false
				drag_ended.emit(placement_data.id, global_position)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if not DecoManager.edit_mode:
			return
		var drag := event as InputEventScreenDrag
		if drag.position.distance_to(_touch_start_pos) >= _DRAG_THRESHOLD:
			_is_dragging = true
		var world_pos := get_viewport().get_canvas_transform().affine_inverse() * drag.position
		if boundary_rect.has_area():
			world_pos.x = clampf(world_pos.x, boundary_rect.position.x, boundary_rect.end.x)
			world_pos.y = clampf(world_pos.y, boundary_rect.position.y, boundary_rect.end.y)
		global_position = world_pos
		get_viewport().set_input_as_handled()
