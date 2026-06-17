class_name Toast
extends Control

@onready var _toast_box: PanelContainer = $ToastBox
@onready var _message_label: Label = $ToastBox/Content/MessageLabel

var _message := ""
var _duration := 2.0

func setup(message: String, duration: float = 2.0) -> Toast:
	_message = message
	_duration = maxf(duration, 0.4)
	if is_node_ready():
		_update_ui()
	return self

func _ready() -> void:
	_update_ui()
	_play()

func _update_ui() -> void:
	_message_label.text = _message

func _play() -> void:
	_toast_box.modulate.a = 0.0
	_toast_box.position.y -= 18.0

	var tween_in := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(_toast_box, "modulate:a", 1.0, 0.18)
	tween_in.tween_property(_toast_box, "position:y", _toast_box.position.y + 18.0, 0.22)
	await tween_in.finished

	await get_tree().create_timer(_duration).timeout

	var tween_out := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_out.tween_property(_toast_box, "modulate:a", 0.0, 0.16)
	tween_out.tween_property(_toast_box, "position:y", _toast_box.position.y - 10.0, 0.16)
	await tween_out.finished
	queue_free()

static func show_message(parent: Node, message: String, duration: float = 2.0) -> Toast:
	var scene := load("res://scenes/ui/components/toast/Toast.tscn") as PackedScene
	if not scene:
		push_error("Toast: Không tìm thấy file Toast.tscn")
		return null

	var canvas := CanvasLayer.new()
	canvas.layer = 220
	parent.get_tree().root.add_child(canvas)

	var toast := scene.instantiate() as Toast
	toast.setup(message, duration)
	canvas.add_child(toast)
	toast.tree_exited.connect(canvas.queue_free)
	return toast
