class_name GiftCodeRedeemDialog
extends Control

@onready var _backdrop: ColorRect = $Backdrop
@onready var _close_btn: Button = $DialogBox/CloseBtn
@onready var _code_input: AuthInput = $DialogBox/Content/Layout/CodeInput
@onready var _status_label: Label = $DialogBox/Content/Layout/StatusLabel
@onready var _redeem_btn: Button = $DialogBox/Content/Layout/ButtonRow/RedeemBtn

const _COLOR_ERROR := Color(0.8, 0.2, 0.2)
const _COLOR_SUCCESS := Color(0.2, 0.6, 0.2)

func _ready() -> void:
	_close_btn.pressed.connect(_on_close_pressed)
	_redeem_btn.pressed.connect(_on_redeem_pressed)
	_backdrop.gui_input.connect(_on_backdrop_input)
	GiftCodeManager.redeem_result_received.connect(_on_redeem_result)
	tree_exiting.connect(_on_tree_exiting)
	GiftCodeManager.resync_after_network_error()
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

func _on_redeem_result(success: bool, message: String) -> void:
	if not is_inside_tree():
		return
	if success:
		_show_status(message, _COLOR_SUCCESS)
		_set_busy(false)
		await get_tree().create_timer(0.8).timeout
		if is_inside_tree():
			queue_free()
		return
	_show_status(message, _COLOR_ERROR)
	_set_busy(GiftCodeManager.is_redeem_in_flight())

func _on_close_pressed() -> void:
	if GiftCodeManager.is_redeem_in_flight():
		return
	queue_free()

func _on_backdrop_input(event: InputEvent) -> void:
	if GiftCodeManager.is_redeem_in_flight():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		queue_free()
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		queue_free()

func _set_busy(busy: bool) -> void:
	_redeem_btn.disabled = busy
	_close_btn.disabled = busy

func _show_status(message: String, color: Color) -> void:
	_status_label.text = message
	_status_label.modulate = color

static func show_dialog(parent: Node) -> GiftCodeRedeemDialog:
	var dialog: GiftCodeRedeemDialog = preload("res://scenes/ui/components/dialog/GiftCodeRedeemDialog.tscn").instantiate()
	parent.add_child(dialog)
	return dialog
