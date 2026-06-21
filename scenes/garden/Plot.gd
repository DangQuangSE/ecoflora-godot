class_name PlotNode
extends Node2D

const FloatLabelScene := preload("res://scenes/garden/FloatLabel.gd")
const TEXTURE_NORMAL  := preload("res://assets/plot/plot.png")
const TEXTURE_WATERED := preload("res://assets/plot/sweet_plot.png")
const WATER_COOLDOWN  := 60
# Y offset (px, negative = up) per stage index [0, 1, 2, 3+]
const _PLANT_Y_OFFSET: Array[float] = [0.0, 0.0, -28.0, -40.0]

@export var plot_id: String = ""

@onready var plot_texture: Sprite2D = $PlotTexture
@onready var plot_sprite: ColorRect  = $PlotSprite
@onready var plant_sprite: Sprite2D  = $PlantSprite
@onready var stage_label: Label      = $StageLabel

var _current_plot: Plot = null
var _dry_timer_active: bool = false

func _ready() -> void:
	plot_sprite.gui_input.connect(_on_plot_gui_input)
	GardenManager.plant_xp_gained.connect(_on_plant_xp_gained)

func setup(plot: Plot, _player: Node2D) -> void:
	plot_id = plot.id
	_current_plot = plot
	_refresh_visual()

func update_plot(plot: Plot) -> void:
	plot_id = plot.id
	_current_plot = plot
	_refresh_visual()

func _refresh_visual() -> void:
	if _current_plot == null:
		return
	if not _current_plot.is_occupied or _current_plot.current_plant == null:
		plot_texture.texture = TEXTURE_NORMAL
		plant_sprite.visible = false
		stage_label.visible = false
		return

	var plant := _current_plot.current_plant
	var stage := plant.current_stage
	var now := int(Time.get_unix_time_from_system())
	var is_watered := (now - plant.last_watered_at) < WATER_COOLDOWN
	plot_texture.texture = TEXTURE_WATERED if is_watered else TEXTURE_NORMAL
	if is_watered and not _dry_timer_active:
		_dry_timer_active = true
		var remaining := WATER_COOLDOWN - (now - plant.last_watered_at)
		get_tree().create_timer(maxf(remaining, 0.1)).timeout.connect(func():
			_dry_timer_active = false
			_refresh_visual()
		, CONNECT_ONE_SHOT)
	stage_label.text = "Lv.%d" % stage
	stage_label.visible = true

	var tex := ItemIconRegistry.get_plant_texture(plant.flower_template_id, stage)
	if tex != null:
		plant_sprite.texture = tex
		plant_sprite.position = Vector2(0.0, _PLANT_Y_OFFSET[clampi(stage, 0, _PLANT_Y_OFFSET.size() - 1)])
		plant_sprite.visible = true
	else:
		plant_sprite.visible = false

func _on_plot_gui_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
				   or (event is InputEventScreenTouch and event.pressed)
	if not is_tap:
		return
	if _current_plot == null:
		return
	if ZoneManager.is_plot_locked(plot_id):
		return
	get_viewport().set_input_as_handled()
	var selected: InventoryItem = InventoryManager.get_selected_item()
	if selected == null:
		if _current_plot.is_occupied:
			if InteractionManager.is_harvest_mode():
				_try_harvest()
			elif InteractionManager.is_dig_up_mode():
				_try_dig_up()
			else:
				InteractionManager.request_show_flower_info(plot_id)
	else:
		_apply_item(selected.get_reference_id(), selected.category)

func _apply_item(ref_id: String, category: InventoryItem.Category) -> void:
	if not _current_plot.is_occupied:
		if category == InventoryItem.Category.SEED:
			InteractionManager.request_plot_action(plot_id, "plant", {"template_id": ref_id})
		return

	if category == InventoryItem.Category.CONSUMABLE:
		var template: FlowerTemplate = GardenManager.get_templates().get(
			_current_plot.current_plant.flower_template_id if _current_plot.current_plant else "", null) as FlowerTemplate
		if template != null and _current_plot.current_plant != null \
				and _current_plot.current_plant.current_stage >= template.get_max_stage_level():
			_spawn_float_label("ĐÃ ĐẠT LEVEL TỐI ĐA", Color(1.0, 0.4, 0.1, 1.0))
			return
		# BE mode: look up item type (0=water, 1=fertilize, 2=pesticide) from cache
		var item_data: Dictionary = GardenManager.get_item_cache().get(ref_id, {})
		if not item_data.is_empty():
			match int(item_data.get("type", -1)):
				0: InteractionManager.request_plot_action(plot_id, "water",      {"ref_id": ref_id})
				1: InteractionManager.request_plot_action(plot_id, "fertilize",  {"ref_id": ref_id})
				2: InteractionManager.request_plot_action(plot_id, "pesticide",  {"ref_id": ref_id})
			return
		# Mock mode fallback: string-based matching
		match ref_id:
			"watering_can": InteractionManager.request_plot_action(plot_id, "water",     {"ref_id": ref_id})
			"fertilizer":   InteractionManager.request_plot_action(plot_id, "fertilize", {"ref_id": ref_id})
			"sickle":
				var stage: int = _current_plot.current_plant.current_stage if _current_plot.current_plant else 0
				var max_stage: FlowerTemplate = GardenManager.get_templates() \
					.get(_current_plot.current_plant.flower_template_id if _current_plot.current_plant else "", null) as FlowerTemplate
				var threshold: int = max_stage.get_max_stage_level() if max_stage else 7
				if stage >= threshold:
					InteractionManager.request_plot_action(plot_id, "harvest")

func _try_harvest() -> void:
	if _current_plot == null or not _current_plot.is_occupied or _current_plot.current_plant == null:
		return
	var template: FlowerTemplate = GardenManager.get_templates().get(
		_current_plot.current_plant.flower_template_id, null) as FlowerTemplate
	if template == null:
		return
	if _current_plot.current_plant.current_stage >= template.get_max_stage_level():
		InteractionManager.request_plot_action(plot_id, "harvest")

func _try_dig_up() -> void:
	if _current_plot == null or not _current_plot.is_occupied or _current_plot.is_pending_sync or _current_plot.current_plant == null:
		return
	var template: FlowerTemplate = GardenManager.get_templates().get(
		_current_plot.current_plant.flower_template_id, null) as FlowerTemplate
	if template == null:
		return
	var flower_name: String = template.name.replace("_", " ") if template.name else "Hoa"
	var dialog: BaseDialog = BaseDialog.show_confirm(
		self,
		"Xúc cây",
		"Bạn chắc chắn muốn xúc %s? Hành động này sẽ mất toàn bộ stage/XP đã trồng.\nCây sẽ trở thành hạt giống Lv0." % flower_name,
		"Xúc",
		"Hủy"
	)
	if dialog == null:
		push_error("PlotNode._try_dig_up: BaseDialog instantiation failed")
		return
	var result := [false]  # boxed in an Array: lambda captures locals by value, this needs a reference type
	dialog.confirmed.connect(func(): result[0] = true, CONNECT_ONE_SHOT)
	dialog.cancelled.connect(func(): result[0] = false, CONNECT_ONE_SHOT)
	await dialog.tree_exited
	if result[0]:
		InteractionManager.request_plot_action(plot_id, "dig_up", {})

func _on_plant_xp_gained(gained_plot_id: String, xp_amount: int, synergy_bonus: int = 0) -> void:
	if gained_plot_id != plot_id:
		return
	if synergy_bonus > 0:
		var base_xp := xp_amount - synergy_bonus
		_spawn_float_label("+%d XP\n+%d 🌿" % [base_xp, synergy_bonus], Color(0.4, 1.0, 0.5, 1.0))
	else:
		_spawn_float_label("+%d XP" % xp_amount)

func _spawn_float_label(text_val: String, color: Color = Color(1, 0.88, 0.1, 1)) -> void:
	var fl := FloatLabelScene.new()
	fl.position = Vector2(0, -60)
	add_child(fl)
	fl.play(text_val, color)

func is_point_inside(world_pos: Vector2) -> bool:
	var local := to_local(world_pos)
	return abs(local.x) <= 32.0 and abs(local.y) <= 32.0

func apply_drag_action() -> void:
	if _current_plot == null or ZoneManager.is_plot_locked(plot_id):
		return
	var selected: InventoryItem = InventoryManager.get_selected_item()
	if selected != null and selected.category != InventoryItem.Category.SEED:
		_apply_item(selected.get_reference_id(), selected.category)
	elif selected == null and InteractionManager.is_harvest_mode() and _current_plot.is_occupied:
		_try_harvest()
