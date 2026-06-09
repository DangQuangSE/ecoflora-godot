class_name LockInfoPopup
extends CanvasLayer

var _root: Control = null

func _init() -> void:
	layer = 12

func show_locked(required_level: int) -> void:
	_build(required_level)
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)

func _dismiss() -> void:
	if not is_instance_valid(self):
		return
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.18).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()

func _build(required_level: int) -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.06, 0.03, 0.01, 0.55)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed) \
		or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			_dismiss()
	)
	_root.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	# PanelContainer auto-resizes to fit its children
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(290, 0)
	var cs := StyleBoxFlat.new()
	cs.bg_color                    = Color(0.96, 0.90, 0.78, 1)
	cs.border_width_left           = 5
	cs.border_width_top            = 5
	cs.border_width_right          = 5
	cs.border_width_bottom         = 5
	cs.border_color                = Color(0.32, 0.18, 0.06, 1)
	cs.corner_radius_top_left      = 20
	cs.corner_radius_top_right     = 20
	cs.corner_radius_bottom_right  = 20
	cs.corner_radius_bottom_left   = 20
	cs.shadow_color                = Color(0, 0, 0, 0.40)
	cs.shadow_size                 = 14
	cs.shadow_offset               = Vector2(2, 5)
	cs.content_margin_left         = 0.0
	cs.content_margin_right        = 0.0
	cs.content_margin_top          = 0.0
	cs.content_margin_bottom       = 0.0
	card.add_theme_stylebox_override("panel", cs)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)

	var vbox := VBoxContainer.new()
	card.add_child(vbox)

	# Header
	var header := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color                    = Color(0.80, 0.64, 0.40, 1)
	hs.border_width_bottom         = 3
	hs.border_color                = Color(0.32, 0.18, 0.06, 0.8)
	hs.corner_radius_top_left      = 15
	hs.corner_radius_top_right     = 15
	hs.content_margin_left         = 14.0
	hs.content_margin_right        = 14.0
	hs.content_margin_top          = 14.0
	hs.content_margin_bottom       = 14.0
	header.add_theme_stylebox_override("panel", hs)
	vbox.add_child(header)

	var hdr_lbl := Label.new()
	hdr_lbl.text = "Khu vực bị khóa"
	hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr_lbl.add_theme_color_override("font_color", Color(0.22, 0.10, 0.02, 1))
	hdr_lbl.add_theme_font_size_override("font_size", 17)
	header.add_child(hdr_lbl)

	# Body
	var body_margin := MarginContainer.new()
	body_margin.add_theme_constant_override("margin_left",   24)
	body_margin.add_theme_constant_override("margin_right",  24)
	body_margin.add_theme_constant_override("margin_top",    18)
	body_margin.add_theme_constant_override("margin_bottom", 22)
	vbox.add_child(body_margin)

	var body_vbox := VBoxContainer.new()
	body_vbox.add_theme_constant_override("separation", 14)
	body_margin.add_child(body_vbox)

	var body_lbl := Label.new()
	body_lbl.text = "Cần đạt Level %d\nđể mở khóa khu vực này!" % required_level
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_lbl.add_theme_color_override("font_color", Color(0.32, 0.18, 0.06, 1))
	body_lbl.add_theme_font_size_override("font_size", 15)
	body_vbox.add_child(body_lbl)

	var btn_center := CenterContainer.new()
	body_vbox.add_child(btn_center)

	var close_btn := Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(80, 36)
	var bs := StyleBoxFlat.new()
	bs.bg_color                   = Color(0.52, 0.18, 0.08, 1)
	bs.border_width_left          = 2
	bs.border_width_top           = 2
	bs.border_width_right         = 2
	bs.border_width_bottom        = 2
	bs.border_color               = Color(0.76, 0.34, 0.18, 1)
	bs.corner_radius_top_left     = 14
	bs.corner_radius_top_right    = 14
	bs.corner_radius_bottom_right = 14
	bs.corner_radius_bottom_left  = 14
	close_btn.add_theme_stylebox_override("normal",   bs)
	close_btn.add_theme_stylebox_override("hover",    bs)
	close_btn.add_theme_stylebox_override("pressed",  bs)
	close_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	close_btn.add_theme_font_size_override("font_size", 15)
	close_btn.pressed.connect(_dismiss)
	btn_center.add_child(close_btn)
