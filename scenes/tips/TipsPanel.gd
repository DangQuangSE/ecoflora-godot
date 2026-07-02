class_name TipsPanelNode
extends Control

@onready var _bg_dimmer: ColorRect      = $BGDimmer
@onready var _close_btn: Button         = $DialogBox/CloseBtn
@onready var _tips_list: VBoxContainer  = $DialogBox/Content/BodyHBox/ContentScroll/TipsList
@onready var _title_label: Label        = $DialogBox/HeaderBox/TitleLabel
@onready var _prev_btn: Button           = $DialogBox/HeaderBox/PrevBtn
@onready var _next_btn: Button           = $DialogBox/HeaderBox/NextBtn

var _style_content := StyleBoxFlat.new()

var _current_tip_id: String = ""
var _tip_ids: Array[String] = []


func _ready() -> void:
	_build_content_style()
	_close_btn.pressed.connect(hide_panel)
	_prev_btn.pressed.connect(_on_prev_pressed)
	_next_btn.pressed.connect(_on_next_pressed)
	_bg_dimmer.gui_input.connect(_on_dimmer_input)
	if TipManager:
		TipManager.tips_updated.connect(_on_tips_updated)
	_load_tips()
	visible = false


func _on_tips_updated(_tips: Array) -> void:
	_load_tips()


func _build_content_style() -> void:
	_style_content.bg_color = Color(0, 0, 0, 0)
	_style_content.border_width_left = 0
	_style_content.border_width_top = 0
	_style_content.border_width_right = 0
	_style_content.border_width_bottom = 0
	_style_content.content_margin_left = 12
	_style_content.content_margin_top = 8
	_style_content.content_margin_right = 12
	_style_content.content_margin_bottom = 8


func _load_tips() -> void:
	_tip_ids.clear()

	var tips := TipManager.get_tips() if TipManager else TipCatalog.build_offline_fallback()
	for tip: GameTip in tips:
		if tip.id.is_empty():
			continue
		_tip_ids.append(tip.id)

	if _tip_ids.size() > 0:
		if _current_tip_id.is_empty() or _current_tip_id not in _tip_ids:
			_set_tip(_tip_ids[0])
		else:
			_refresh_content()
			_update_navigation_buttons()
	else:
		_update_navigation_buttons()


func show_panel() -> void:
	if TipManager and TipManager.get_tips().is_empty():
		await TipManager.refresh_async()
	if _current_tip_id.is_empty() and _tip_ids.size() > 0:
		_set_tip(_tip_ids[0])
	else:
		_refresh_content()
		_update_navigation_buttons()
	visible = true


func hide_panel() -> void:
	if visible:
		hide()


func _set_tip(tip_id: String) -> void:
	_current_tip_id = tip_id
	_update_navigation_buttons()
	_refresh_content()


func _update_navigation_buttons() -> void:
	var has_multiple_tips := _tip_ids.size() > 1
	_prev_btn.visible = has_multiple_tips
	_next_btn.visible = has_multiple_tips


func _on_prev_pressed() -> void:
	if _tip_ids.is_empty():
		return
	var idx := _tip_ids.find(_current_tip_id)
	if idx == -1:
		idx = 0
	var next_idx := (idx - 1 + _tip_ids.size()) % _tip_ids.size()
	_set_tip(_tip_ids[next_idx])


func _on_next_pressed() -> void:
	if _tip_ids.is_empty():
		return
	var idx := _tip_ids.find(_current_tip_id)
	if idx == -1:
		idx = 0
	var next_idx := (idx + 1) % _tip_ids.size()
	_set_tip(_tip_ids[next_idx])


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

	# Cập nhật động tiêu đề trực tiếp lên label
	if _title_label:
		_title_label.text = tip.title

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _style_content)
	_tips_list.add_child(card)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(content)

	var body := Label.new()
	body.text = tip.content
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_constant_override("line_spacing", 5)
	body.add_theme_color_override("font_color", Color(0.24, 0.14, 0.05, 1))
	content.add_child(body)


func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
	elif event is InputEventScreenTouch and event.pressed:
		hide_panel()
