extends Node2D

const DecoNodeScene := preload("res://scenes/shared/DecoNode.tscn")

@onready var _player: Player = $Player
@onready var _hud           = $HUD

var _deco_layer: Node2D = null
var _boundary_rect: Rect2 = Rect2()

func _ready() -> void:
	_connect_hud_joystick()
	if not has_node("DemoSchool"):
		return
	_deco_layer = get_node("DecoLayer") as Node2D
	_boundary_rect = _compute_boundary()
	_player.setup_camera_world_limits(_boundary_rect)
	_player.set_movement_bounds(_boundary_rect)
	SceneTransition.apply_spawn_origin(self, _player)
	DecoManager.placements_loaded.connect(_on_placements_loaded)
	DecoManager.deco_placed.connect(_on_deco_placed)
	DecoManager.deco_recalled.connect(_on_deco_recalled)
	DecoManager.batch_save_failed.connect(_on_batch_save_failed)
	DecoManager.init_scene("school")

func _connect_hud_joystick() -> void:
	if _hud.has_signal("joystick_direction_changed"):
		_hud.connect("joystick_direction_changed", _player.set_move_direction)
		return
	var joystick := _hud.get_node_or_null("DynamicJoystick")
	if joystick != null and joystick.has_signal("direction_changed"):
		joystick.connect("direction_changed", _player.set_move_direction)

func _exit_tree() -> void:
	if DecoManager.placements_loaded.is_connected(_on_placements_loaded):
		DecoManager.placements_loaded.disconnect(_on_placements_loaded)
	if DecoManager.deco_placed.is_connected(_on_deco_placed):
		DecoManager.deco_placed.disconnect(_on_deco_placed)
	if DecoManager.deco_recalled.is_connected(_on_deco_recalled):
		DecoManager.deco_recalled.disconnect(_on_deco_recalled)
	if DecoManager.batch_save_failed.is_connected(_on_batch_save_failed):
		DecoManager.batch_save_failed.disconnect(_on_batch_save_failed)
	DecoManager.exit_scene()

func _compute_boundary() -> Rect2:
	var bg := get_node_or_null("DemoSchool") as Sprite2D
	if bg == null or bg.texture == null:
		return Rect2()
	var tex_size := Vector2(bg.texture.get_width(), bg.texture.get_height())
	var world_size := tex_size * bg.scale
	if bg.centered:
		return Rect2(bg.global_position - world_size / 2.0, world_size)
	return Rect2(bg.global_position, world_size)

func _on_placements_loaded(placements: Array) -> void:
	if _deco_layer == null:
		return
	for child in _deco_layer.get_children():
		child.queue_free()
	for p: Variant in placements:
		var dp := p as DecoPlacement
		if dp != null:
			_spawn_deco_node(dp)

func _spawn_deco_node(p: DecoPlacement) -> void:
	var node: DecoNode = DecoManager.get_deco_scene(p.decor_slug).instantiate()
	node.placement_data = p
	node.boundary_rect = _boundary_rect
	node.global_position = Vector2(p.position_x, p.position_y)
	node.tapped.connect(_on_deco_tapped)
	node.drag_ended.connect(_on_deco_drag_ended)
	_deco_layer.add_child(node)

func _on_deco_placed(placement: DecoPlacement) -> void:
	if _deco_layer == null:
		return
	if placement.id.begins_with("temp_"):
		_spawn_deco_node(placement)
		return
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn == null or dn.placement_data == null:
			continue
		if dn.placement_data.id.begins_with("temp_"):
			dn.placement_data = placement
			return
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn != null and dn.placement_data != null and dn.placement_data.id == placement.id:
			return
	_spawn_deco_node(placement)

func _on_deco_recalled(placement_id: String) -> void:
	if _deco_layer == null:
		return
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn != null and dn.placement_data != null and dn.placement_data.id == placement_id:
			child.queue_free()
			return

func _on_deco_tapped(placement_id: String) -> void:
	if _hud.has_method("show_recall_btn"):
		_hud.call("show_recall_btn", placement_id)

func _on_deco_drag_ended(placement_id: String, new_pos: Vector2) -> void:
	if _deco_layer == null:
		return
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn != null and dn.placement_data != null and dn.placement_data.id == placement_id:
			dn.placement_data.position_x = new_pos.x
			dn.placement_data.position_y = new_pos.y
			DecoManager.batch_move_async([{"id": placement_id, "x": new_pos.x, "y": new_pos.y}])
			return

func _on_batch_save_failed() -> void:
	if _deco_layer == null:
		return
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn != null and dn.placement_data != null:
			dn.global_position = Vector2(dn.placement_data.position_x, dn.placement_data.position_y)

func _unhandled_input(event: InputEvent) -> void:
	if _deco_layer == null:
		return
	var selected := InventoryManager.get_selected_item()
	if selected == null or selected.category != InventoryItem.Category.DECOR:
		return
	if DecoManager.edit_mode:
		return
	var world_pos: Vector2
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		world_pos = get_viewport().get_canvas_transform().affine_inverse() * event.position
	elif event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and (event as InputEventMouseButton).pressed:
		world_pos = get_global_mouse_position()
	else:
		return
	DecoManager.place_deco_async(selected.id, world_pos.x, world_pos.y)
	get_viewport().set_input_as_handled()
