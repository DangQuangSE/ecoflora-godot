class_name BaseDialog
extends Control

signal confirmed
signal cancelled

@onready var backdrop: ColorRect = $Backdrop
@onready var dialog_box: Control = $DialogBox
@onready var title_label: Label = $DialogBox/Content/Layout/TitleLabel
@onready var message_label: Label = $DialogBox/Content/Layout/MessageScroll/MessageLabel
@onready var confirm_btn: Button = $DialogBox/Content/Layout/ButtonRow/ConfirmBtn
@onready var cancel_btn: Button = $DialogBox/CancelBtn

var _title: String = "Thông báo"
var _message: String = ""
var _confirm_text: String = "Xác nhận"
var _cancel_text: String = ""

# Khởi tạo thông tin hiển thị cho Dialog
func setup(title: String, message: String, confirm_text: String = "Xác nhận", cancel_text: String = "") -> BaseDialog:
	_title = title
	_message = message
	_confirm_text = confirm_text
	_cancel_text = cancel_text
	
	# Nếu các node đã sẵn sàng thì cập nhật ngay
	if is_inside_tree():
		_update_ui()
	return self

func _ready() -> void:
	_update_ui()
	
	# Kết nối sự kiện nút bấm
	confirm_btn.pressed.connect(func() -> void: dismiss(true))
	cancel_btn.pressed.connect(func() -> void: dismiss(false))
	
	# Hiệu ứng xuất hiện (Pop-in)
	backdrop.modulate.a = 0.0
	var tween_back := create_tween()
	tween_back.tween_property(backdrop, "modulate:a", 1.0, 0.15)
	
	dialog_box.scale = Vector2(0.7, 0.7)
	dialog_box.modulate.a = 0.0
	var tween_box := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_box.tween_property(dialog_box, "scale", Vector2(1.0, 1.0), 0.25)
	tween_box.tween_property(dialog_box, "modulate:a", 1.0, 0.2)

func _update_ui() -> void:
	title_label.text = _title
	message_label.text = _message
	confirm_btn.text = _confirm_text
	
	if _cancel_text.is_empty():
		cancel_btn.visible = false
	else:
		cancel_btn.visible = true

# Đóng Dialog với hiệu ứng thu nhỏ và mờ dần (Pop-out)
func dismiss(accepted: bool) -> void:
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
		
	var tween_back := create_tween()
	tween_back.tween_property(backdrop, "modulate:a", 0.0, 0.15)
	
	var tween_box := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_box.tween_property(dialog_box, "scale", Vector2(0.8, 0.8), 0.15)
	tween_box.tween_property(dialog_box, "modulate:a", 0.0, 0.15)
	
	await tween_box.finished
	queue_free()

# Xử lý phím Enter để xác nhận và Escape để hủy
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		dismiss(true)
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismiss(false)

# Phương thức tĩnh tiện ích để hiển thị Alert Dialog (chỉ có nút Xác nhận)
static func show_alert(parent: Node, title: String, message: String, confirm_text: String = "Xác nhận") -> BaseDialog:
	var scene := load("res://scenes/ui/components/dialog/BaseDialog.tscn") as PackedScene
	if not scene:
		push_error("BaseDialog: Không tìm thấy file BaseDialog.tscn")
		return null
	var dialog := scene.instantiate() as BaseDialog
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	parent.get_tree().root.add_child(canvas)
	canvas.add_child(dialog)
	# Tự dọn dẹp CanvasLayer khi dialog bị xóa
	dialog.tree_exited.connect(canvas.queue_free)
	dialog.setup(title, message, confirm_text, "")
	return dialog

# Phương thức tĩnh tiện ích để hiển thị Confirm Dialog (có cả nút Xác nhận và Hủy)
static func show_confirm(parent: Node, title: String, message: String, confirm_text: String = "Xác nhận", cancel_text: String = "Hủy") -> BaseDialog:
	var scene := load("res://scenes/ui/components/dialog/BaseDialog.tscn") as PackedScene
	if not scene:
		push_error("BaseDialog: Không tìm thấy file BaseDialog.tscn")
		return null
	var dialog := scene.instantiate() as BaseDialog
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	parent.get_tree().root.add_child(canvas)
	canvas.add_child(dialog)
	# Tự dọn dẹp CanvasLayer khi dialog bị xóa
	dialog.tree_exited.connect(canvas.queue_free)
	dialog.setup(title, message, confirm_text, cancel_text)
	return dialog
