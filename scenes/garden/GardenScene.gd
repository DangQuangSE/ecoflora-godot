extends Node2D

const PlotScene           := preload("res://scenes/garden/Plot.tscn")
const FlowerInfoCardScene := preload("res://scenes/garden/FlowerInfoCard.tscn")
const CloudOverlayScene   := preload("res://scenes/garden/CloudOverlay.tscn")
const UnlockBannerScene   := preload("res://scenes/garden/UnlockBanner.tscn")

@onready var _player: Player = $Player
@onready var _hud: HUD       = $HUD

var _plot_nodes: Array[PlotNode] = []
var _flower_info_card: CanvasLayer = null
var _active_banner: CanvasLayer = null
var _active_banner_zone_id: String = ""
var _pending_notifications: Array[String] = []

func _ready() -> void:
	WeatherManager.set_overlay_visible(true)
	_hud.joystick_direction_changed.connect(_player.set_move_direction)
	_setup_camera()
	_spawn_plots()
	_spawn_flower_info_card()
	_spawn_zone_overlays()
	GardenManager.plots_updated.connect(_on_plots_updated)
	ZoneManager.zone_notification.connect(_on_zone_notification)
	ZoneManager.zone_unlocked.connect(_on_zone_unlocked)

func _setup_camera() -> void:
	_player.setup_camera_limits(Rect2i(), Vector2i(16, 16))

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
	var plot: Plot = GardenManager.get_plot(plot_id)
	if plot == null or not plot.is_occupied or plot.current_plant == null:
		return
	var template: FlowerTemplate = GardenManager.get_templates().get(plot.current_plant.flower_template_id)
	if template == null:
		return
	_flower_info_card.call("show_flower", plot_id, plot.current_plant, template)

func _spawn_zone_overlays() -> void:
	for zone: ZoneDefinition in ZoneManager.get_all_zones():
		var overlay: Node2D = CloudOverlayScene.instantiate()
		overlay.call("setup", zone.zone_id)
		overlay.position = zone.world_position
		add_child(overlay)

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

func _on_zone_unlocked(zone_id: String) -> void:
	if _active_banner != null and is_instance_valid(_active_banner) and zone_id == _active_banner_zone_id:
		_active_banner.call("dismiss")

func _exit_tree() -> void:
	if GardenManager.plots_updated.is_connected(_on_plots_updated):
		GardenManager.plots_updated.disconnect(_on_plots_updated)
	if InteractionManager.show_flower_info.is_connected(_on_show_flower_info):
		InteractionManager.show_flower_info.disconnect(_on_show_flower_info)
	if ZoneManager.zone_notification.is_connected(_on_zone_notification):
		ZoneManager.zone_notification.disconnect(_on_zone_notification)
	if ZoneManager.zone_unlocked.is_connected(_on_zone_unlocked):
		ZoneManager.zone_unlocked.disconnect(_on_zone_unlocked)
	if _active_banner != null and is_instance_valid(_active_banner):
		_active_banner.queue_free()
		_active_banner = null

func _on_plots_updated(plots: Array[Plot]) -> void:
	for i in range(mini(plots.size(), _plot_nodes.size())):
		_plot_nodes[i].update_plot(plots[i])
