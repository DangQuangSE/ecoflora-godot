class_name PlotNode
extends Node2D

@export var plot_id: String = ""

@onready var plot_sprite: ColorRect  = $PlotSprite
@onready var plant_sprite: Sprite2D  = $PlantSprite
@onready var stage_label: Label      = $StageLabel
@onready var popup: CanvasLayer      = $Popup
@onready var btn_add_xp: Button      = $Popup/PopupPanel/VBox/BtnAddXP

var _current_plot: Plot = null

const SOIL_COLOR_EMPTY    := Color(0.6, 0.4, 0.2, 1)
const SOIL_COLOR_OCCUPIED := Color(0.45, 0.32, 0.18, 1)

func _ready() -> void:
	btn_add_xp.pressed.connect(_on_btn_add_xp_pressed)
	plot_sprite.gui_input.connect(_on_plot_gui_input)
	popup.visible = false

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
	if not is_tap or _current_plot == null:
		return

	get_viewport().set_input_as_handled()

	if not _current_plot.is_occupied:
		var selected := InventoryManager.get_selected_item()
		if selected != null and selected.category == InventoryItem.Category.SEED:
			InteractionManager.request_plot_action(plot_id, "plant", {"template_id": selected.get_reference_id()})
	else:
		var stage := _current_plot.current_plant.current_stage if _current_plot.current_plant else 0
		if stage >= 7:
			InteractionManager.request_plot_action(plot_id, "harvest")
		elif not popup.visible:
			popup.visible = true

func _on_btn_add_xp_pressed() -> void:
	InteractionManager.request_plot_action(plot_id, "next_stage")
	popup.visible = false
