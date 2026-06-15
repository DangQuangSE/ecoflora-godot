class_name TipsPanelNode
extends Control

@onready var _bg_dimmer: ColorRect      = $BGDimmer
@onready var _close_btn: Button         = $PanelRoot/VBox/TitleBar/CloseBtn
@onready var _tabs_container: HBoxContainer = $PanelRoot/VBox/Tabs
@onready var _tips_list: VBoxContainer  = $PanelRoot/VBox/Scroll/TipsList

var _style_tab_normal := StyleBoxFlat.new()
var _style_tab_active := StyleBoxFlat.new()
var _style_tab_hover := StyleBoxFlat.new()

var _current_category_id: String = ""
var _tab_buttons: Array[Button] = []
var _category_ids: Array[String] = []


func _ready() -> void:
	_build_tab_styles()
	_close_btn.pressed.connect(hide_panel)
	_bg_dimmer.gui_input.connect(_on_dimmer_input)
	_build_tabs()
	visible = false


func _build_tab_styles() -> void:
	for s in [_style_tab_normal, _style_tab_active, _style_tab_hover]:
		s.corner_radius_top_left = 8
		s.corner_radius_top_right = 8
		s.border_width_left = 1
		s.border_width_top = 1
		s.border_width_right = 1
	_style_tab_normal.bg_color = Color(0.40, 0.24, 0.10, 1)
	_style_tab_normal.border_color = Color(0.62, 0.44, 0.24, 1)
	_style_tab_active.bg_color = Color(0.76, 0.55, 0.30, 1)
	_style_tab_active.border_color = Color(0.95, 0.78, 0.50, 1)
	_style_tab_active.border_width_top = 2
	_style_tab_hover.bg_color = Color(0.52, 0.34, 0.16, 1)
	_style_tab_hover.border_color = Color(0.72, 0.52, 0.30, 1)


func _build_tabs() -> void:
	for child in _tabs_container.get_children():
		child.queue_free()
	_tab_buttons.clear()
	_category_ids.clear()

	var categories := TipCatalog.get_categories()
	for cat: Dictionary in categories:
		var cat_id: String = str(cat.get("id", ""))
		var label: String = str(cat.get("label", ""))
		if cat_id.is_empty():
			continue
		var btn := Button.new()
		btn.text = label
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(func() -> void: _set_category(cat_id))
		_tabs_container.add_child(btn)
		_tab_buttons.append(btn)
		_category_ids.append(cat_id)

	if _category_ids.size() > 0:
		_set_category(_category_ids[0])


func show_panel() -> void:
	if _current_category_id.is_empty() and _category_ids.size() > 0:
		_set_category(_category_ids[0])
	else:
		_refresh_tips_list()
		_update_tab_styles()
	visible = true
	AudioManager.play_sfx("res://sounds/item_bag_click.wav")


func hide_panel() -> void:
	if visible:
		AudioManager.play_sfx("res://sounds/item_bag_click.wav")
		hide()


func _set_category(category_id: String) -> void:
	_current_category_id = category_id
	_update_tab_styles()
	_refresh_tips_list()


func _update_tab_styles() -> void:
	for i in range(_tab_buttons.size()):
		var is_active: bool = (_category_ids[i] == _current_category_id)
		var btn := _tab_buttons[i]
		btn.add_theme_stylebox_override("normal", _style_tab_active if is_active else _style_tab_normal)
		btn.add_theme_stylebox_override("pressed", _style_tab_active)
		btn.add_theme_stylebox_override("hover", _style_tab_active if is_active else _style_tab_hover)
		btn.add_theme_color_override(
			"font_color",
			Color(0.18, 0.09, 0.02, 1) if is_active else Color(1.0, 0.92, 0.72, 1)
		)
		btn.add_theme_constant_override("outline_size", 2)
		btn.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.95))


func _refresh_tips_list() -> void:
	for child in _tips_list.get_children():
		child.queue_free()

	var tips := TipCatalog.get_tips_for_category(_current_category_id)
	for tip: GameTip in tips:
		var title := Label.new()
		title.text = tip.title
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 16)
		title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1))
		title.add_theme_constant_override("outline_size", 1)
		title.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.9))
		_tips_list.add_child(title)

		var body := Label.new()
		body.text = tip.body
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 14)
		body.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78, 1))
		_tips_list.add_child(body)

		var sep := HSeparator.new()
		sep.modulate = Color(0.38, 0.52, 0.28, 0.5)
		_tips_list.add_child(sep)


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
	elif event is InputEventScreenTouch and event.pressed:
		hide_panel()
