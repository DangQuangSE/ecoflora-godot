class_name CloudOverlay
extends Node2D

var _zone_id: String = ""
var _required_level: int = 0
var _tappable: bool = false
var _pulse_tween: Tween = null
var _panel: Panel = null
var _tap_label: Label = null
var _border_style: StyleBoxFlat = null
var _input_ctrl: Control = null

const SIZE := Vector2(360.0, 228.0)
const COLOR_BORDER_LOCKED := Color(0.45, 0.40, 0.65, 0.75)
const COLOR_BORDER_NOTIFIED := Color(1.0, 0.80, 0.20, 1.0)

func setup(zone_id: String) -> void:
	_zone_id = zone_id
	var zone := ZoneManager.get_zone(zone_id)
	if zone:
		_required_level = zone.required_level

func _ready() -> void:
	z_index = 5
	_build_ui()
	ZoneManager.zone_notification.connect(_on_notified)
	ZoneManager.zone_unlocked.connect(_on_unlocked)
	var state := ZoneManager.get_zone_state(_zone_id)
	if state == ZoneManager.ZoneState.NOTIFIED:
		_on_notified(_zone_id)
	elif state == ZoneManager.ZoneState.UNLOCKED:
		queue_free()

func _build_ui() -> void:
	_input_ctrl = Control.new()
	_input_ctrl.size = SIZE
	_input_ctrl.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_input_ctrl)
	_input_ctrl.gui_input.connect(_on_rect_gui_input)

	_border_style = StyleBoxFlat.new()
	_border_style.bg_color = Color(0.06, 0.06, 0.12, 0.88)
	_border_style.set_corner_radius_all(20)
	_border_style.set_border_width_all(2)
	_border_style.border_color = COLOR_BORDER_LOCKED

	_panel = Panel.new()
	_panel.size = SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _border_style)
	_input_ctrl.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.size = Vector2(200.0, 190.0)
	vbox.position = Vector2(20.0, 25.0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_input_ctrl.add_child(vbox)

	var lock_lbl := Label.new()
	lock_lbl.text = "🔒"
	lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_lbl.add_theme_font_size_override("font_size", 52)
	lock_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lock_lbl)

	var level_lbl := Label.new()
	level_lbl.text = "Cần Lv.%d\nđể mở khóa" % _required_level
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_lbl.add_theme_color_override("font_color", Color(0.88, 0.84, 1.00))
	level_lbl.add_theme_font_size_override("font_size", 15)
	level_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(level_lbl)

	_tap_label = Label.new()
	_tap_label.text = "✨ Chạm để mở!"
	_tap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	_tap_label.add_theme_font_size_override("font_size", 14)
	_tap_label.visible = false
	_tap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tap_label)

func _on_notified(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = true
	_tap_label.visible = true
	_border_style.border_color = COLOR_BORDER_NOTIFIED
	_border_style.set_border_width_all(3)
	_start_pulse()

func _start_pulse() -> void:
	if _pulse_tween != null:
		_pulse_tween.kill()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_tap_label, "modulate:a", 0.25, 0.55)
	_pulse_tween.tween_property(_tap_label, "modulate:a", 1.0, 0.55)

func _on_unlocked(zone_id: String) -> void:
	if zone_id != _zone_id:
		return
	_tappable = false
	if _pulse_tween != null:
		_pulse_tween.kill()
		_pulse_tween = null
	if ZoneManager.zone_notification.is_connected(_on_notified):
		ZoneManager.zone_notification.disconnect(_on_notified)
	if ZoneManager.zone_unlocked.is_connected(_on_unlocked):
		ZoneManager.zone_unlocked.disconnect(_on_unlocked)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	await tween.finished
	if is_instance_valid(self):
		queue_free()

func _on_rect_gui_input(event: InputEvent) -> void:
	if not _tappable:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = (event as InputEventMouseButton).pressed
	elif event is InputEventScreenTouch:
		pressed = (event as InputEventScreenTouch).pressed
	if pressed:
		get_viewport().set_input_as_handled()
		ZoneManager.request_unlock(_zone_id)
