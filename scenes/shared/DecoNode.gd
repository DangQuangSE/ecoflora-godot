class_name DecoNode
extends Sprite2D

signal tapped(placement_id: String)
signal drag_ended(placement_id: String, new_pos: Vector2)

@export var auto_configure_shapes: bool = true

var placement_data: DecoPlacement
var boundary_rect: Rect2 = Rect2()

var _area: Area2D
var _pressing: bool = false
var _drag_active: bool = false
var _hold_elapsed: float = 0.0
var _press_start_screen: Vector2 = Vector2.ZERO
var _base_scale: float = 1.0

var _static_body: StaticBody2D
var _static_collision: CollisionShape2D

const _TAP_MAX_SEC: float = 0.3
const _DRAG_THRESHOLD: float = 12.0
const _HOLD_DURATION: float = 0.8
const _DISPLAY_PX: float = 100.0
const _DRAG_SCALE: float = 1.15
const _LARGE_SLUGS: PackedStringArray = ["warterfall", "warter_tower"]

func _ready() -> void:
	_area = $Area2D
	var shape_node := $Area2D/CollisionShape2D as CollisionShape2D
	if placement_data == null:
		push_warning("DecoNode: placement_data is null")
		return
	
	# Reference StaticBody2D / CollisionShape2D if they exist in the scene tree
	_static_body = get_node_or_null("StaticBody2D")
	if _static_body:
		_static_collision = _static_body.get_node_or_null("CollisionShape2D")
	
	# Connect to edit mode state changes
	DecoManager.edit_mode_changed.connect(_on_edit_mode_changed)
	
	var tex := ItemIconRegistry.get_icon(placement_data.decor_slug)
	texture = tex
	if tex != null:
		if auto_configure_shapes:
			var display_px := _DISPLAY_PX * (4.0 if placement_data.decor_slug in _LARGE_SLUGS else 1.0)
			_base_scale = display_px / maxf(tex.get_width(), tex.get_height())
			scale = Vector2(_base_scale, _base_scale)
			
			# Set Area2D shape for detection (drag/recall)
			var rect_shape := RectangleShape2D.new()
			rect_shape.size = tex.get_size()
			shape_node.shape = rect_shape
		else:
			# Keep the custom scale designed in the Editor scene
			_base_scale = scale.x
		
		# Set initial state of collision shape if manually defined in the scene
		if _static_collision:
			_static_collision.disabled = DecoManager.edit_mode
		
	_area.input_event.connect(_on_area_input_event)

func _on_edit_mode_changed(is_edit: bool) -> void:
	if _static_collision:
		_static_collision.set_deferred("disabled", is_edit)

func _process(delta: float) -> void:
	if not _pressing or _drag_active:
		return
	_hold_elapsed += delta
	if _hold_elapsed >= _HOLD_DURATION:
		_drag_active = true
		scale = Vector2(_base_scale * _DRAG_SCALE, _base_scale * _DRAG_SCALE)

func _on_area_input_event(_vp: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_start_press(touch.position)
		elif _pressing:
			_end_press(touch.position)
	elif event is InputEventScreenDrag:
		if not _drag_active:
			return
		_move_to_screen((event as InputEventScreenDrag).position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_start_press(mb.position)

func _input(event: InputEvent) -> void:
	if not _pressing:
		return
	if event is InputEventMouseMotion:
		if _drag_active:
			_move_to_screen(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_end_press(mb.position)

func _start_press(screen_pos: Vector2) -> void:
	_pressing = true
	_drag_active = false
	_hold_elapsed = 0.0
	_press_start_screen = screen_pos
	get_viewport().set_input_as_handled()

func _end_press(screen_pos: Vector2) -> void:
	if _drag_active:
		_drag_active = false
		_pressing = false
		scale = Vector2(_base_scale, _base_scale)
		drag_ended.emit(placement_data.id, global_position)
		get_viewport().set_input_as_handled()
		return
	_pressing = false
	var dist := screen_pos.distance_to(_press_start_screen)
	if dist < _DRAG_THRESHOLD and _hold_elapsed < _TAP_MAX_SEC:
		tapped.emit(placement_data.id)
		get_viewport().set_input_as_handled()

func _move_to_screen(screen_pos: Vector2) -> void:
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	if boundary_rect.has_area():
		world_pos.x = clampf(world_pos.x, boundary_rect.position.x, boundary_rect.end.x)
		world_pos.y = clampf(world_pos.y, boundary_rect.position.y, boundary_rect.end.y)
	global_position = world_pos
