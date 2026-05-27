extends Node

signal plots_updated(plots: Array[Plot])
signal plant_failed(plot_id: String, reason: String)
signal harvest_completed(plot_id: String, product_id: String)
signal plant_xp_gained(plot_id: String, xp_amount: int)

const GARDEN_ID := "main_garden"

var _plots: Array[Plot] = []
var _templates: Dictionary = {}

# World positions for 16 plots — initial 8 (2×4 grid) + zone_1 (plots 8–11) + zone_2 (plots 12–15)
# Zone positions are placeholders — adjust to fit TileMap layout in Godot Editor
const PLOT_POSITIONS: Array[Vector2] = [
	Vector2(80, 80),   Vector2(200, 80),
	Vector2(80, 200),  Vector2(200, 200),
	Vector2(80, 320),  Vector2(200, 320),
	Vector2(80, 440),  Vector2(200, 440),
	Vector2(360, 80),  Vector2(480, 80),
	Vector2(360, 200), Vector2(480, 200),
	Vector2(360, 320), Vector2(480, 320),
	Vector2(360, 440), Vector2(480, 440),
]

func _ready() -> void:
	var garden_svc := MockGardenService.new()
	_plots = garden_svc.get_initial_plots(GARDEN_ID)
	for t: FlowerTemplate in garden_svc.get_flower_templates():
		_templates[t.id] = t
	harvest_completed.connect(func(_plot_id: String, product_id: String) -> void:
		InventoryManager.add_harvest_product(product_id)
	)
	InteractionManager.plot_action_requested.connect(_on_plot_action)

func get_plots() -> Array[Plot]:
	return _plots

func get_plot_position(index: int) -> Vector2:
	if index < PLOT_POSITIONS.size():
		return PLOT_POSITIONS[index]
	return Vector2.ZERO

func get_templates() -> Dictionary:
	return _templates

func get_plot(plot_id: String) -> Plot:
	return _find_plot(plot_id)

func water(plot_id: String) -> void:
	const WATER_XP := 20
	var plot := _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	plot.is_pending_sync = true
	plot.current_plant.current_xp += WATER_XP
	plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
	plant_xp_gained.emit(plot_id, WATER_XP)
	plots_updated.emit(_plots)
	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func fertilize(plot_id: String) -> void:
	const FERTILIZE_XP := 50
	var plot := _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	plot.is_pending_sync = true
	plot.current_plant.current_xp += FERTILIZE_XP
	plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
	plant_xp_gained.emit(plot_id, FERTILIZE_XP)
	plots_updated.emit(_plots)
	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func plant(plot_id: String, flower_template_id: String) -> void:
	var plot := _find_plot(plot_id)
	if plot == null or plot.is_occupied or plot.is_pending_sync:
		plant_failed.emit(plot_id, "not_available")
		return
	var template: FlowerTemplate = _templates.get(flower_template_id)
	if template == null:
		plant_failed.emit(plot_id, "unknown_template")
		return
	# Consume seed authoritatively here — after all guards pass, before optimistic update
	if not InventoryManager.consume_seed(flower_template_id):
		plant_failed.emit(plot_id, "no_seed")
		return

	plot.is_pending_sync = true
	var flower := PlantedFlower.new(flower_template_id, "")
	flower.current_xp = 0
	flower.current_stage = template.compute_stage_for_xp(0)
	plot.plant(flower)
	plots_updated.emit(_plots)

	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func debug_add_xp(plot_id: String, xp_amount: int) -> void:
	var plot := _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return

	plot.is_pending_sync = true
	plot.current_plant.current_xp += xp_amount
	plot.current_plant.current_stage = template.compute_stage_for_xp(plot.current_plant.current_xp)
	plots_updated.emit(_plots)

	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func harvest(plot_id: String) -> void:
	var plot := _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	if plot.current_plant.current_stage < template.get_max_stage_level():
		return

	plot.is_pending_sync = true
	var product_id := template.harvest_product_id
	plot.clear()
	plots_updated.emit(_plots)
	harvest_completed.emit(plot_id, product_id)

	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func _find_plot(plot_id: String) -> Plot:
	for p: Plot in _plots:
		if p.id == plot_id:
			return p
	return null

func debug_next_stage(plot_id: String) -> void:
	var plot := _find_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.is_pending_sync:
		return
	var template: FlowerTemplate = _templates.get(plot.current_plant.flower_template_id)
	if template == null:
		return
	var next_xp := template.get_next_stage_xp(plot.current_plant.current_stage)
	if next_xp < 0:
		return
	plot.is_pending_sync = true
	plot.current_plant.current_xp = next_xp
	plot.current_plant.current_stage = template.compute_stage_for_xp(next_xp)
	plots_updated.emit(_plots)
	await get_tree().process_frame
	plot.is_pending_sync = false
	plots_updated.emit(_plots)

func _on_plot_action(plot_id: String, action: String, data: Dictionary) -> void:
	match action:
		"plant":      plant(plot_id, data.get("template_id", ""))
		"harvest":    harvest(plot_id)
		"water":      water(plot_id)
		"fertilize":  fertilize(plot_id)
		"add_xp":     debug_add_xp(plot_id, data.get("amount", 500))
		"next_stage": debug_next_stage(plot_id)
