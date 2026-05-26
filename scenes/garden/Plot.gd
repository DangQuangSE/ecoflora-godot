class_name PlotNode
extends Node2D

const FloatLabelScene := preload("res://scenes/garden/FloatLabel.gd")

@export var plot_id: String = ""

@onready var plot_sprite: ColorRect = $PlotSprite
@onready var plant_sprite: Sprite2D = $PlantSprite
@onready var stage_label: Label     = $StageLabel

var _current_plot: Plot = null
var _applied_this_gesture: bool = false

const SOIL_COLOR_EMPTY    := Color(0.6, 0.4, 0.2, 1)
const SOIL_COLOR_OCCUPIED := Color(0.45, 0.32, 0.18, 1)

func _ready() -> void:
	plot_sprite.gui_input.connect(_on_plot_gui_input)
	plot_sprite.mouse_exited.connect(func(): _applied_this_gesture = false)
	GardenManager.plant_xp_gained.connect(_on_plant_xp_gained)

func setup(plot: Plot, _player: Node2D) -> void:
	plot_id = plot.id
	_current_plot = plot
	_refresh_visual()

func update_plot(plot: Plot) -> void:
	_current_plot = plot
	_refresh_visual()

func _process(_delta: float) -> void:
	pass

func _refresh_visual() -> void:
	if _current_plot == null:
		return
	if not _current_plot.is_occupied or _current_plot.current_plant == null:
		plot_sprite.color = SOIL_COLOR_EMPTY
		plant_sprite.visible = false
		stage_label.visible = false
		return

	var plant := _current_plot.current_plant
	var stage := plant.current_stage
	plot_sprite.color = SOIL_COLOR_OCCUPIED
	stage_label.text = "Lv.%d" % stage
	stage_label.visible = true

	var tex := ItemIconRegistry.get_plant_texture(plant.flower_template_id, stage)
	if tex != null:
		plant_sprite.texture = tex
		plant_sprite.visible = true
	else:
		plant_sprite.visible = false

func _on_plot_gui_input(event: InputEvent) -> void:
	var is_tap: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) \
				   or (event is InputEventScreenTouch and event.pressed)
	var is_drag: bool = (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) \
				   or (event is InputEventScreenDrag)

	if not is_tap and not is_drag:
		return
	if _current_plot == null:
		return

	get_viewport().set_input_as_handled()

	var selected := InventoryManager.get_selected_item()

	if is_tap:
		_applied_this_gesture = false
		if selected == null:
			if _current_plot.is_occupied:
				InteractionManager.request_show_flower_info(plot_id)
		else:
			_apply_item(selected.get_reference_id(), selected.category)
	elif is_drag and not _applied_this_gesture:
		_applied_this_gesture = true
		if selected != null:
			_apply_item(selected.get_reference_id(), selected.category)

func _apply_item(ref_id: String, category: InventoryItem.Category) -> void:
	if not _current_plot.is_occupied:
		if category == InventoryItem.Category.SEED:
			InteractionManager.request_plot_action(plot_id, "plant", {"template_id": ref_id})
		return

	match ref_id:
		"watering_can":
			InteractionManager.request_plot_action(plot_id, "water")
		"fertilizer":
			InteractionManager.request_plot_action(plot_id, "fertilize")
		"sickle":
			var stage := _current_plot.current_plant.current_stage if _current_plot.current_plant else 0
			if stage >= 7:
				InteractionManager.request_plot_action(plot_id, "harvest")

func _on_plant_xp_gained(gained_plot_id: String, xp_amount: int) -> void:
	if gained_plot_id == plot_id:
		_spawn_float_label("+%d XP" % xp_amount)

func _spawn_float_label(text_val: String) -> void:
	var fl := FloatLabelScene.new()
	fl.position = Vector2(0, -60)
	add_child(fl)
	fl.play(text_val)
