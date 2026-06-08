class_name FlowerInfoCard
extends CanvasLayer

@onready var _dimmer: ColorRect    = $Dimmer
@onready var _card: Panel          = $Card
@onready var _close_btn: Button    = $Card/Content/HeaderPanel/HBox/CloseBtn
@onready var _icon: TextureRect    = $Card/Content/HeaderPanel/HBox/Icon
@onready var _name_label: Label    = $Card/Content/HeaderPanel/HBox/InfoVBox/NameLabel
@onready var _level_label: Label   = $Card/Content/HeaderPanel/HBox/InfoVBox/LevelLabel
@onready var _xp_bar: ProgressBar  = $Card/Content/BodyMargin/BodyVBox/XPBar
@onready var _xp_label: Label      = $Card/Content/BodyMargin/BodyVBox/XPLabel
@onready var _desc_label: Label    = $Card/Content/BodyMargin/BodyVBox/DescLabel
@onready var _action_btn: Button   = $Card/Content/BodyMargin/BodyVBox/ActionBtn

var _current_plot_id: String = ""

func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(close_card)
	_dimmer.gui_input.connect(_on_dimmer_input)
	_action_btn.pressed.connect(_on_harvest_pressed)
	GardenManager.plots_updated.connect(_on_plots_updated)

func show_flower(plot_id: String, plant: PlantedFlower, template: FlowerTemplate) -> void:
	_current_plot_id = plot_id
	_icon.texture = ItemIconRegistry.get_icon(plant.flower_template_id)
	_name_label.text = template.name
	_refresh_plant_data(plant, template)
	_desc_label.text = _get_description(plant.flower_template_id)
	visible = true
	_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_card, "modulate:a", 1.0, 0.20).set_ease(Tween.EASE_OUT)

func close_card() -> void:
	visible = false
	_current_plot_id = ""

func _refresh_plant_data(plant: PlantedFlower, template: FlowerTemplate) -> void:
	_level_label.text = "Lv.%d" % plant.current_stage
	var next_xp := template.get_next_stage_xp(plant.current_stage)
	var cur_xp  := template.get_xp_required_for_stage(plant.current_stage)
	if next_xp > 0:
		_xp_bar.max_value = next_xp - cur_xp
		_xp_bar.value     = plant.current_xp - cur_xp
		_xp_label.text    = "%d / %d XP" % [plant.current_xp, next_xp]
	else:
		_xp_bar.max_value = 1
		_xp_bar.value     = 1
		_xp_label.text    = "MAX LEVEL"
	_action_btn.visible = plant.current_stage >= template.get_max_stage_level()

func _on_dimmer_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		close_card()

func _on_harvest_pressed() -> void:
	InteractionManager.request_plot_action(_current_plot_id, "harvest")
	close_card()

func _on_plots_updated(plots: Array[Plot]) -> void:
	if not visible or _current_plot_id.is_empty():
		return
	for plot: Plot in plots:
		if plot.id != _current_plot_id:
			continue
		if not plot.is_occupied or plot.current_plant == null:
			close_card()
			return
		var template: FlowerTemplate = GardenManager.get_templates().get(plot.current_plant.flower_template_id)
		if template != null:
			_refresh_plant_data(plot.current_plant, template)
		return

func _get_description(template_id: String) -> String:
	var template: FlowerTemplate = GardenManager.get_templates().get(template_id)
	if template == null:
		return ""
	match template.name.to_lower():
		"anthurium":         return "Hoa anthurium — sắc đỏ rực rỡ, biểu tượng của lòng nhiệt thành."
		"lotus":             return "Hoa sen — biểu tượng của sự thanh khiết và vẻ đẹp tinh khôi."
		"periwinkle":        return "Hoa dừa cạn — sức sống bền bỉ, nở hoa quanh năm."
		"purple_bellflower": return "Hoa chuông tím — thanh lịch và nhẹ nhàng như tiếng chuông chiều."
		"rose":              return "Hoa hồng — loài hoa của tình yêu và sự lãng mạn."
		"sun_flower":        return "Hoa hướng dương — luôn hướng về ánh sáng, tràn đầy năng lượng."
		"tulip":             return "Hoa tulip — vẻ đẹp thanh tao, biểu tượng của sự hoàn hảo."
		_:                   return ""
