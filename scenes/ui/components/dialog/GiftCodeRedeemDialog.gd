class_name GiftCodeRedeemDialog
extends Control

@onready var _backdrop: ColorRect = $Backdrop
@onready var _close_btn: Button = $DialogBox/CloseBtn
@onready var _code_input: AuthInput = $DialogBox/Content/Layout/CodeInput
@onready var _paste_btn: TextureButton = $DialogBox/Content/Layout/CodeInput/PasteButton
@onready var _status_label: Label = $DialogBox/Content/Layout/StatusLabel
@onready var _redeem_btn: Button = $DialogBox/Content/Layout/ButtonRow/RedeemBtn

const _COLOR_ERROR := Color(0.8, 0.2, 0.2)

func _ready() -> void:
	_close_btn.pressed.connect(_on_close_pressed)
	_paste_btn.pressed.connect(_on_paste_pressed)
	_redeem_btn.pressed.connect(_on_redeem_pressed)
	_backdrop.gui_input.connect(_on_backdrop_input)
	GiftCodeManager.redeem_result_received.connect(_on_redeem_result)
	tree_exiting.connect(_on_tree_exiting)
	GiftCodeManager.resync_after_network_error()
	_apply_code_input_padding()
	_code_input.focus_field()
	_set_busy(GiftCodeManager.is_redeem_in_flight())

func _on_tree_exiting() -> void:
	if GiftCodeManager.redeem_result_received.is_connected(_on_redeem_result):
		GiftCodeManager.redeem_result_received.disconnect(_on_redeem_result)

func _on_redeem_pressed() -> void:
	if GiftCodeManager.is_redeem_in_flight():
		return
	var code := _code_input.strip_edges()
	if code.is_empty():
		_show_status("Vui lòng nhập mã.", _COLOR_ERROR)
		return
	_show_status("", _COLOR_ERROR)
	_set_busy(true)
	GiftCodeManager.redeem_async(code)

func _on_paste_pressed() -> void:
	var clipboard_text := DisplayServer.clipboard_get().strip_edges()
	if clipboard_text.is_empty():
		_show_status("Clipboard đang trống.", _COLOR_ERROR)
		return
	_code_input.text = clipboard_text
	var field := _code_input.get_line_edit()
	field.grab_focus()
	field.caret_column = field.text.length()
	_show_status("", _COLOR_ERROR)

func _on_redeem_result(success: bool, message: String) -> void:
	if not is_inside_tree():
		return
	if success:
		# Reward feedback is shown via Toast (GiftCodeManager), close immediately.
		_set_busy(false)
		queue_free()
		return
	_show_status(message, _COLOR_ERROR)
	_set_busy(GiftCodeManager.is_redeem_in_flight())

func _on_close_pressed() -> void:
	queue_free()

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		queue_free()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		queue_free()

func _set_busy(busy: bool) -> void:
	_redeem_btn.disabled = busy

func _show_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.modulate = color

func _apply_code_input_padding() -> void:
	var field := _code_input.get_line_edit()
	for style_name in ["normal", "focus", "read_only"]:
		var style := field.get_theme_stylebox(style_name, "LineEdit").duplicate()
		style.set_content_margin(SIDE_RIGHT, maxf(style.get_content_margin(SIDE_RIGHT), 44.0))
		field.add_theme_stylebox_override(style_name, style)

static func show_dialog(parent: Node) -> GiftCodeRedeemDialog:
	var dialog: GiftCodeRedeemDialog = preload("res://scenes/ui/components/dialog/GiftCodeRedeemDialog.tscn").instantiate()
	var canvas := CanvasLayer.new()
	canvas.layer = 200
	parent.get_tree().root.add_child(canvas)
	canvas.add_child(dialog)
	dialog.tree_exited.connect(canvas.queue_free)
	return dialog
