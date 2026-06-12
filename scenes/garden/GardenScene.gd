extends Node2D

const PlotScene           := preload("res://scenes/garden/Plot.tscn")
const FlowerInfoCardScene := preload("res://scenes/garden/FlowerInfoCard.tscn")
const CloudOverlayScene   := preload("res://scenes/garden/CloudOverlay.tscn")
const UnlockBannerScene   := preload("res://scenes/garden/UnlockBanner.tscn")
const DecoNodeScene       := preload("res://scenes/shared/DecoNode.tscn")
const SynergyIndicatorScene := preload("res://scenes/garden/SynergyZoneIndicator.tscn")

@onready var _player: Player           = $Player
@onready var _hud: HUD                 = $HUD
@onready var _plot_anchors: Node2D     = $PlotAnchors
@onready var _deco_layer: Node2D       = $DecoLayer

var _plot_nodes: Array[PlotNode] = []
var _flower_info_card: CanvasLayer = null
var _active_banner: CanvasLayer = null
var _active_banner_zone_id: String = ""
var _pending_notifications: Array[String] = []
var _drag_applied: Dictionary = {}
var _boundary_rect: Rect2 = Rect2()
var _synergy_indicators: Dictionary = {}
var _plot_anchors_flat: Array[Node] = []

func _ready() -> void:
	WeatherManager.set_overlay_visible(true)
	_hud.joystick_direction_changed.connect(_player.set_move_direction)
	_setup_camera()
	SceneTransition.apply_spawn_origin(self, _player)
	_spawn_plots()
	_spawn_flower_info_card()
	_spawn_zone_overlays()
	_cache_plot_anchors()
	_spawn_synergy_indicators()
	_refresh_synergy_indicators()
	GardenManager.plots_updated.connect(_on_plots_updated)
	if GardenManager.icons_registered.is_connected(_refresh_synergy_indicators) == false:
		GardenManager.icons_registered.connect(_refresh_synergy_indicators)
	ZoneManager.zone_notification.connect(_on_zone_notification)
	if FocusManager.has_recovery_penalty:
		FocusManager.has_recovery_penalty = false
		_show_recovery_toast()
	ZoneManager.zone_unlocked.connect(_on_zone_unlocked)
	_boundary_rect = _compute_boundary()
	DecoManager.placements_loaded.connect(_on_placements_loaded)
	DecoManager.deco_placed.connect(_on_deco_placed)
	DecoManager.deco_recalled.connect(_on_deco_recalled)
	DecoManager.batch_save_failed.connect(_on_batch_save_failed)
	DecoManager.init_scene("garden")

func _setup_camera() -> void:
	_player.setup_camera_limits(Rect2i(), Vector2i(16, 16))

func _spawn_plots() -> void:
	var plots := GardenManager.get_plots()
	var anchors: Array[Node] = []
	for zone in _plot_anchors.get_children():
		anchors.append_array(zone.get_children())
	for i in range(plots.size()):
		var node: PlotNode = PlotScene.instantiate()
		add_child(node)
		node.global_position = anchors[i].global_position if i < anchors.size() else GardenManager.get_plot_position(i)
		node.setup(plots[i], _player)
		_plot_nodes.append(node)

func _spawn_flower_info_card() -> void:
	_flower_info_card = FlowerInfoCardScene.instantiate()
	add_child(_flower_info_card)
	InteractionManager.show_flower_info.connect(_on_show_flower_info)

func _on_show_flower_info(plot_id: String) -> void:
	var plot: Plot = GardenManager.get_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.current_plant == null:
		return
	var template: FlowerTemplate = GardenManager.get_templates().get(plot.current_plant.flower_template_id)
	if template == null:
		return
	_flower_info_card.call("show_flower", plot_id, plot.current_plant, template)

func _cache_plot_anchors() -> void:
	_plot_anchors_flat.clear()
	for zone_node in _plot_anchors.get_children():
		_plot_anchors_flat.append_array(zone_node.get_children())

func _spawn_synergy_indicators() -> void:
	for zone_id: String in ZonePlotMap.get_all_zone_ids():
		var indices: Array[int] = ZonePlotMap.get_plot_indices_for_zone(zone_id)
		var plot_ids: Array[String] = []
		for idx: int in indices:
			plot_ids.append("plot_%d" % idx)
		var layout: Dictionary = _zone_isometric_layout(plot_ids)
		var indicator: SynergyZoneIndicator = SynergyIndicatorScene.instantiate()
		add_child(indicator)
		indicator.setup(
			zone_id,
			layout["center"],
			layout["axis_u"],
			layout["plot_globals"]
		)
		_synergy_indicators[zone_id] = indicator

func _zone_isometric_layout(plot_ids: Array[String]) -> Dictionary:
	var globals: PackedVector2Array = PackedVector2Array()
	for pid: String in plot_ids:
		if not pid.begins_with("plot_"):
			continue
		var idx := pid.trim_prefix("plot_").to_int()
		if idx < _plot_anchors_flat.size():
			globals.append((_plot_anchors_flat[idx] as Node2D).global_position)

	if globals.size() < 3:
		var bounds: Dictionary = _zone_bounds(plot_ids)
		return {
			"center": bounds["center"],
			"axis_u": Vector2.RIGHT,
			"plot_globals": globals,
		}

	var center := Vector2.ZERO
	for gp: Vector2 in globals:
		center += gp
	center /= float(globals.size())

	var axis_u: Vector2 = (globals[1] - globals[0]).normalized()
	return {
		"center": center,
		"axis_u": axis_u,
		"plot_globals": globals,
	}

func _zone_bounds(plot_ids: Array[String]) -> Dictionary:
	var min_p := Vector2(INF, INF)
	var max_p := Vector2(-INF, -INF)
	for pid: String in plot_ids:
		if not pid.begins_with("plot_"):
			continue
		var idx := pid.trim_prefix("plot_").to_int()
		if idx < _plot_anchors_flat.size():
			var gp: Vector2 = (_plot_anchors_flat[idx] as Node2D).global_position
			min_p.x = minf(min_p.x, gp.x)
			min_p.y = minf(min_p.y, gp.y)
			max_p.x = maxf(max_p.x, gp.x)
			max_p.y = maxf(max_p.y, gp.y)
	if min_p.x == INF:
		return {"center": Vector2.ZERO, "extents": Vector2(80, 60)}
	var center := (min_p + max_p) * 0.5
	var half := (max_p - min_p) * 0.5
	return {"center": center, "extents": half + Vector2(24.0, 20.0)}

func _zone_center_pos(plot_ids: Array[String]) -> Vector2:
	return (_zone_bounds(plot_ids)["center"] as Vector2)

func _refresh_synergy_indicators() -> void:
	var plots: Array[Plot] = GardenManager.get_plots()
	var plots_by_index: Dictionary = {}
	for p: Plot in plots:
		plots_by_index[p.plot_index] = p
	var templates: Dictionary = GardenManager.get_templates()
	var synergy_cache: Dictionary = GardenManager.get_synergy_cache()
	for zone_id: String in ZonePlotMap.get_all_zone_ids():
		var indicator: SynergyZoneIndicator = _synergy_indicators.get(zone_id, null)
		if indicator == null:
			continue
		var indices: Array[int] = ZonePlotMap.get_plot_indices_for_zone(zone_id)
		var result: Dictionary = SynergyEvaluator.evaluate_zone_with_cache(
			indices, plots_by_index, templates, synergy_cache)
		indicator.set_active(
			result.get("active", false),
			str(result.get("synergy_name", ""))
		)

func _spawn_zone_overlays() -> void:
	var anchors: Array[Node] = []
	for zone_node in _plot_anchors.get_children():
		anchors.append_array(zone_node.get_children())
	for zone: ZoneDefinition in ZoneManager.get_all_zones():
		var overlay: CloudOverlay = CloudOverlayScene.instantiate()
		overlay.setup(zone.zone_id)
		overlay.position = _zone_overlay_pos(zone.plot_ids, anchors) + overlay.pos_offset
		add_child(overlay)

func _zone_overlay_pos(plot_ids: Array[String], anchors: Array[Node]) -> Vector2:
	var min_x := INF
	var min_y := INF
	for pid: String in plot_ids:
		if not pid.begins_with("plot_"):
			continue
		var idx := pid.trim_prefix("plot_").to_int()
		if idx < anchors.size():
			var gp: Vector2 = (anchors[idx] as Node2D).global_position
			if gp.x < min_x: min_x = gp.x
			if gp.y < min_y: min_y = gp.y
	if min_x == INF:
		return Vector2.ZERO
	return Vector2(min_x - 60.0, min_y - 38.0)

func _on_zone_notification(zone_id: String) -> void:
	_pending_notifications.append(zone_id)
	_flush_notification_queue()

func _flush_notification_queue() -> void:
	if _pending_notifications.is_empty():
		return
	if _active_banner != null and is_instance_valid(_active_banner):
		return
	_active_banner_zone_id = _pending_notifications.pop_front()
	_active_banner = UnlockBannerScene.instantiate()
	get_tree().root.add_child(_active_banner)
	_active_banner.connect("dismissed", _on_banner_dismissed)
	_active_banner.call("show_for_zone", _active_banner_zone_id)

func _on_banner_dismissed() -> void:
	_active_banner = null
	_active_banner_zone_id = ""
	_flush_notification_queue()

func _show_recovery_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	var lbl := Label.new()
	lbl.text = "⚠ Session học bị gián đoạn\n-20 XP đã bị trừ"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lbl.position.y = 80.0
	layer.add_child(lbl)
	add_child(layer)
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_callback(layer.queue_free)

func _on_zone_unlocked(zone_id: String) -> void:
	if _active_banner != null and is_instance_valid(_active_banner) and zone_id == _active_banner_zone_id:
		_active_banner.call("dismiss")

func _exit_tree() -> void:
	if GardenManager.plots_updated.is_connected(_on_plots_updated):
		GardenManager.plots_updated.disconnect(_on_plots_updated)
	if GardenManager.icons_registered.is_connected(_refresh_synergy_indicators):
		GardenManager.icons_registered.disconnect(_refresh_synergy_indicators)
	if InteractionManager.show_flower_info.is_connected(_on_show_flower_info):
		InteractionManager.show_flower_info.disconnect(_on_show_flower_info)
	if ZoneManager.zone_notification.is_connected(_on_zone_notification):
		ZoneManager.zone_notification.disconnect(_on_zone_notification)
	if ZoneManager.zone_unlocked.is_connected(_on_zone_unlocked):
		ZoneManager.zone_unlocked.disconnect(_on_zone_unlocked)
	if _active_banner != null and is_instance_valid(_active_banner):
		_active_banner.queue_free()
		_active_banner = null
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
	var bg := get_node_or_null("Background") as Sprite2D
	if bg == null or bg.texture == null:
		return Rect2()
	var tex_size := Vector2(bg.texture.get_width(), bg.texture.get_height())
	var world_size := tex_size * bg.scale
	if bg.centered:
		return Rect2(bg.global_position - world_size / 2.0, world_size)
	return Rect2(bg.global_position, world_size)

func _on_placements_loaded(placements: Array) -> void:
	for child in _deco_layer.get_children():
		child.queue_free()
	for p: Variant in placements:
		var dp := p as DecoPlacement
		if dp != null:
			_spawn_deco_node(dp)

func _spawn_deco_node(p: DecoPlacement) -> void:
	var node: DecoNode = DecoNodeScene.instantiate()
	node.placement_data = p
	node.boundary_rect = _boundary_rect
	node.global_position = Vector2(p.position_x, p.position_y)
	node.tapped.connect(_on_deco_tapped)
	node.drag_ended.connect(_on_deco_drag_ended)
	_deco_layer.add_child(node)

func _on_deco_placed(placement: DecoPlacement) -> void:
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
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn != null and dn.placement_data != null and dn.placement_data.id == placement_id:
			child.queue_free()
			return

func _on_deco_tapped(placement_id: String) -> void:
	_hud.show_recall_btn(placement_id)

func _on_deco_drag_ended(placement_id: String, new_pos: Vector2) -> void:
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn != null and dn.placement_data != null and dn.placement_data.id == placement_id:
			dn.placement_data.position_x = new_pos.x
			dn.placement_data.position_y = new_pos.y
			DecoManager.batch_move_async([{"id": placement_id, "x": new_pos.x, "y": new_pos.y}])
			return

func _on_batch_save_failed() -> void:
	for child in _deco_layer.get_children():
		var dn := child as DecoNode
		if dn != null and dn.placement_data != null:
			dn.global_position = Vector2(dn.placement_data.position_x, dn.placement_data.position_y)

func _unhandled_input(event: InputEvent) -> void:
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

func _process(_delta: float) -> void:
	# Mouse drag — polled every frame, immune to Control input-capture
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_drag_applied.clear()
		return
	var selected := InventoryManager.get_selected_item()
	if selected == null and not InteractionManager.is_harvest_mode():
		return
	if selected != null and selected.category in [InventoryItem.Category.SEED, InventoryItem.Category.DECOR]:
		return
	var world_pos := get_global_mouse_position()
	for pn: PlotNode in _plot_nodes:
		if pn.plot_id in _drag_applied:
			continue
		if pn.is_point_inside(world_pos):
			_drag_applied[pn.plot_id] = true
			pn.apply_drag_action()

func _input(event: InputEvent) -> void:
	# Touch drag (mobile) — separate from mouse, _process doesn't cover touch
	if event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		_drag_applied.clear()
		return
	if not (event is InputEventScreenDrag):
		return
	var selected := InventoryManager.get_selected_item()
	if selected == null and not InteractionManager.is_harvest_mode():
		return
	if selected != null and selected.category in [InventoryItem.Category.SEED, InventoryItem.Category.DECOR]:
		return
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * (event as InputEventScreenDrag).position
	for pn: PlotNode in _plot_nodes:
		if pn.plot_id in _drag_applied:
			continue
		if pn.is_point_inside(world_pos):
			_drag_applied[pn.plot_id] = true
			pn.apply_drag_action()

func _on_plots_updated(plots: Array[Plot]) -> void:
	for i in range(mini(plots.size(), _plot_nodes.size())):
		_plot_nodes[i].update_plot(plots[i])
	_refresh_synergy_indicators()
