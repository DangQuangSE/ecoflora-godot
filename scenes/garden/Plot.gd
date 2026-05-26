class_name PlotNode
extends Node2D

@export var plot_id: String = ""
@export var proximity_radius: float = 80.0

@onready var plot_sprite: ColorRect = $PlotSprite
@onready var stage_label: Label = $StageLabel
@onready var popup: CanvasLayer = $Popup
@onready var btn_plant: Button = $Popup/PopupPanel/VBox/BtnPlant
@onready var btn_harvest: Button = $Popup/PopupPanel/VBox/BtnHarvest
@onready var btn_add_xp: Button = $Popup/PopupPanel/VBox/BtnAddXP
@onready var seed_options: VBoxContainer = $Popup/PopupPanel/VBox/SeedOptions

var _player_ref: Node2D = null
var _current_plot: Plot = null

const STAGE_COLORS := {
	0: Color(0.6, 0.4, 0.2, 1),
	1: Color(0.4, 0.8, 0.2, 1),
	4: Color(0.1, 0.6, 0.1, 1),
	7: Color(1.0, 0.85, 0.0, 1),
}

func _ready() -> void:
	btn_plant.pressed.connect(_on_btn_plant_pressed)
	btn_harvest.pressed.connect(_on_btn_harvest_pressed)
	btn_add_xp.pressed.connect(_on_btn_add_xp_pressed)
	var btn_sunflower: Button = $Popup/PopupPanel/VBox/SeedOptions/BtnSunflower
	var btn_rose: Button = $Popup/PopupPanel/VBox/SeedOptions/BtnRose
	btn_sunflower.pressed.connect(_on_btn_sunflower_pressed)
	btn_rose.pressed.connect(_on_btn_rose_pressed)
	popup.visible = false

func setup(plot: Plot, player: Node2D) -> void:
	plot_id = plot.id
	_current_plot = plot
	_player_ref = player
	_refresh_visual()

func update_plot(plot: Plot) -> void:
	_current_plot = plot
	_refresh_visual()

func _process(_delta: float) -> void:
	if _player_ref == null:
		return
	var in_range := global_position.distance_to(_player_ref.global_position) <= proximity_radius
	popup.visible = in_range

func _refresh_visual() -> void:
	if _current_plot == null:
		return
	var stage := 0
	if _current_plot.is_occupied and _current_plot.current_plant != null:
		stage = _current_plot.current_plant.current_stage

	var color_key := 0
	if stage >= 7:
		color_key = 7
	elif stage >= 4:
		color_key = 4
	elif stage >= 1:
		color_key = 1
	plot_sprite.color = STAGE_COLORS.get(color_key, STAGE_COLORS[0])

	if _current_plot.is_occupied:
		stage_label.text = "Lv.%d" % stage
		stage_label.visible = true
	else:
		stage_label.visible = false

	var is_harvest_ready := _current_plot.is_occupied and stage >= 7
	btn_plant.visible = not _current_plot.is_occupied
	btn_harvest.visible = is_harvest_ready
	btn_add_xp.visible = _current_plot.is_occupied and not is_harvest_ready
	seed_options.visible = false

func _on_btn_plant_pressed() -> void:
	seed_options.visible = not seed_options.visible

func _on_btn_sunflower_pressed() -> void:
	_plant_flower("sunflower")

func _on_btn_rose_pressed() -> void:
	_plant_flower("rose")

func _plant_flower(template_id: String) -> void:
	# UI guard only — authoritative seed consumption happens in GardenManager.plant()
	if InventoryManager.has_seed(template_id):
		InteractionManager.request_plot_action(plot_id, "plant", {"template_id": template_id})
	seed_options.visible = false

func _on_btn_harvest_pressed() -> void:
	InteractionManager.request_plot_action(plot_id, "harvest")

func _on_btn_add_xp_pressed() -> void:
	InteractionManager.request_plot_action(plot_id, "add_xp", {"amount": 150})
