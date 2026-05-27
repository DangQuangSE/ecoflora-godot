class_name UnlockBanner
extends CanvasLayer

signal dismissed

@onready var _panel: Panel = $Panel
@onready var _label: Label = $Panel/Label
@onready var _close_btn: Button = $Panel/CloseButton

var _is_closing: bool = false

func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(dismiss)

func show_for_zone(zone_id: String) -> void:
	_is_closing = false
	var zone_num := zone_id.trim_prefix("zone_")
	_label.text = "Khu vườn %s đã mở khóa!\nTap đám mây để xua tan." % zone_num
	visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.25)

func dismiss() -> void:
	if _is_closing:
		return
	_is_closing = true
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 0.0, 0.15)
	await tween.finished
	if is_instance_valid(self):
		dismissed.emit()
		queue_free()
