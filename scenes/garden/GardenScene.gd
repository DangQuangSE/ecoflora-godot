extends Node2D

const PlotScene         := preload("res://scenes/garden/Plot.tscn")
const FlowerInfoCardScene := preload("res://scenes/garden/FlowerInfoCard.tscn")

@onready var _player: Player        = $Player
@onready var _hud: HUD              = $HUD
@onready var _tilemap: TileMapLayer = $GameTileMap/grass

var _plot_nodes: Array[PlotNode] = []
var _flower_info_card: CanvasLayer = null

func _ready() -> void:
	_hud.joystick_direction_changed.connect(_player.set_move_direction)
	_setup_camera()
	_spawn_plots()
	_spawn_flower_info_card()
	GardenManager.plots_updated.connect(_on_plots_updated)

func _setup_camera() -> void:
	if not _tilemap.tile_set:
		push_error("GardenScene: TileMapLayer has no TileSet assigned")
		_player.setup_camera_limits(Rect2i(), Vector2i(16, 16))
		return
	var used_rect: Rect2i   = _tilemap.get_used_rect()
	var tile_size: Vector2i = _tilemap.tile_set.tile_size
	_player.setup_camera_limits(used_rect, tile_size)

func _spawn_plots() -> void:
	var plots := GardenManager.get_plots()
	for i in range(plots.size()):
		var node: PlotNode = PlotScene.instantiate()
		add_child(node)
		node.global_position = GardenManager.get_plot_position(i)
		node.setup(plots[i], _player)
		_plot_nodes.append(node)

func _spawn_flower_info_card() -> void:
	_flower_info_card = FlowerInfoCardScene.instantiate()
	add_child(_flower_info_card)
	InteractionManager.show_flower_info.connect(_on_show_flower_info)

func _on_show_flower_info(plot_id: String) -> void:
	var plot := GardenManager.get_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.current_plant == null:
		return
	var template: FlowerTemplate = GardenManager.get_templates().get(plot.current_plant.flower_template_id)
	if template == null:
		return
	_flower_info_card.call("show_flower", plot_id, plot.current_plant, template)

func _exit_tree() -> void:
	GardenManager.plots_updated.disconnect(_on_plots_updated)
	if InteractionManager.show_flower_info.is_connected(_on_show_flower_info):
		InteractionManager.show_flower_info.disconnect(_on_show_flower_info)

func _on_plots_updated(plots: Array[Plot]) -> void:
	for i in range(mini(plots.size(), _plot_nodes.size())):
		_plot_nodes[i].update_plot(plots[i])
