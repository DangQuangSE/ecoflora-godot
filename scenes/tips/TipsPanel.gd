class_name TipsPanelNode
extends Control

@onready var _bg_dimmer: ColorRect      = $BGDimmer
@onready var _close_btn: Button         = $PanelRoot/VBox/TitleBar/CloseBtn
@onready var _tabs_container: HBoxContainer = $PanelRoot/VBox/Tabs
@onready var _tips_list: VBoxContainer  = $PanelRoot/VBox/Scroll/TipsList

var _style_tab_normal := StyleBoxFlat.new()
var _style_tab_active := StyleBoxFlat.new()
var _style_tab_hover := StyleBoxFlat.new()

var _current_tip_id: String = ""
var _tab_buttons: Array[Button] = []
var _tip_ids: Array[String] = []


func _ready() -> void:
	_build_tab_styles()
	_close_btn.pressed.connect(hide_panel)
	_bg_dimmer.gui_input.connect(_on_dimmer_input)
	if TipManager:
		TipManager.tips_updated.connect(_on_tips_updated)
	_build_tabs()
	visible = false


func _on_tips_updated(_tips: Array) -> void:
	_build_tabs()


func _build_tab_styles() -> void:
	for s in [_style_tab_normal, _style_tab_active, _style_tab_hover]:
		s.corner_radius_top_left = 12
		s.corner_radius_top_right = 12
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.border_color = Color(0.45, 0.27, 0.09, 1)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 7
		s.content_margin_bottom = 9
	_style_tab_normal.bg_color = Color(0.55, 0.32, 0.12, 1)
	_style_tab_hover.bg_color = Color(0.68, 0.43, 0.18, 1)
	_style_tab_active.bg_color = Color(1.0, 0.93, 0.74, 1)
	_style_tab_active.border_color = Color(0.78, 0.49, 0.16, 1)


func _build_tabs() -> void:
	for child in _tabs_container.get_children():
		child.queue_free()
	_tab_buttons.clear()
	_tip_ids.clear()

	var tips := TipManager.get_tips() if TipManager else TipCatalog.build_offline_fallback()
	for tip: GameTip in tips:
		if tip.id.is_empty():
			continue
		var btn := Button.new()
		btn.text = tip.title
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(func() -> void: _set_tip(tip.id))
		_tabs_container.add_child(btn)
		_tab_buttons.append(btn)
		_tip_ids.append(tip.id)

	if _tip_ids.size() > 0:
		if _current_tip_id.is_empty() or _current_tip_id not in _tip_ids:
			_set_tip(_tip_ids[0])
		else:
			_refresh_content()
			_update_tab_styles()


func show_panel() -> void:
	if TipManager and TipManager.get_tips().is_empty():
		await TipManager.refresh_async()
	if _current_tip_id.is_empty() and _tip_ids.size() > 0:
		_set_tip(_tip_ids[0])
	else:
		_refresh_content()
		_update_tab_styles()
	visible = true


func hide_panel() -> void:
	if visible:
		hide()


func _set_tip(tip_id: String) -> void:
	_current_tip_id = tip_id
	_update_tab_styles()
	_refresh_content()


func _update_tab_styles() -> void:
	for i in range(_tab_buttons.size()):
		var is_active: bool = (_tip_ids[i] == _current_tip_id)
		var btn := _tab_buttons[i]
		btn.add_theme_stylebox_override("normal", _style_tab_active if is_active else _style_tab_normal)
		btn.add_theme_stylebox_override("pressed", _style_tab_active)
		btn.add_theme_stylebox_override("hover", _style_tab_active if is_active else _style_tab_hover)
		btn.add_theme_color_override(
			"font_color",
			Color(0.61, 0.31, 0.07, 1) if is_active else Color(0.97, 0.86, 0.60, 1)
		)
		btn.add_theme_color_override(
			"font_hover_color",
			Color(0.61, 0.31, 0.07, 1) if is_active else Color(0.97, 0.86, 0.60, 1)
		)
		btn.add_theme_color_override("font_pressed_color", Color(0.61, 0.31, 0.07, 1))
		btn.add_theme_constant_override("outline_size", 2 if is_active else 1)
		btn.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.95))


func _find_current_tip() -> GameTip:
	var tips := TipManager.get_tips() if TipManager else TipCatalog.build_offline_fallback()
	for tip: GameTip in tips:
		if tip.id == _current_tip_id:
			return tip
	return null


func _refresh_content() -> void:
	for child in _tips_list.get_children():
		child.queue_free()

	var tip := _find_current_tip()
	if tip == null:
		return

	var title := Label.new()
	title.text = tip.title
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.55, 0.28, 0.06, 1))
	title.add_theme_constant_override("outline_size", 1)
	title.add_theme_color_override("font_outline_color", Color(0.97, 0.86, 0.60, 0.35))
	_tips_list.add_child(title)

	var body := Label.new()
	body.text = tip.content
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", Color(0.38, 0.24, 0.10, 1))
	_tips_list.add_child(body)


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
	elif event is InputEventScreenTouch and event.pressed:
		hide_panel()
