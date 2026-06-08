extends Control

const LOGIN_SCENE := "res://scenes/auth/LoginScene.tscn"
const GARDEN_SCENE := "res://scenes/garden/GardenScene.tscn"

@onready var _first_name_field: LineEdit = $RegisterFrame/FormArea/CenterContainer/FormContent/FirstNameWrapper/FirstNameField
@onready var _last_name_field: LineEdit = $RegisterFrame/FormArea/CenterContainer/FormContent/LastNameWrapper/LastNameField
@onready var _account_field: LineEdit = $RegisterFrame/FormArea/CenterContainer/FormContent/AccountWrapper/AccountField
@onready var _password_field: LineEdit = $RegisterFrame/FormArea/CenterContainer/FormContent/PasswordWrapper/PasswordField
@onready var _confirm_password_field: LineEdit = $RegisterFrame/FormArea/CenterContainer/FormContent/ConfirmPasswordWrapper/ConfirmPasswordField
@onready var _register_btn: Button = $RegisterFrame/FormArea/CenterContainer/FormContent/RegisterBtnMargin/RegisterBtn
@onready var _login_link: Button = $RegisterFrame/FormArea/CenterContainer/FormContent/LoginLink
@onready var _error_label: Label = $RegisterFrame/FormArea/CenterContainer/FormContent/ErrorLabel
@onready var _loading: ColorRect = $LoadingOverlay
@onready var _loading_label: Label = $LoadingOverlay/LoadingLabel

func _ready() -> void:
	SceneTransition.force_clear()
	WeatherManager.set_overlay_visible(false)
	_apply_theme()
	_error_label.visible = false
	_loading.visible = false
	_register_btn.pressed.connect(_on_register_pressed)
	_login_link.pressed.connect(_on_login_link_pressed)
	_confirm_password_field.gui_input.connect(_on_confirm_password_gui_input)

	UserManager.register_succeeded.connect(on_register_success)
	UserManager.register_failed.connect(show_error)

	if UserManager.is_logged_in():
		SceneTransition.fade_to(GARDEN_SCENE)
		return

	_first_name_field.grab_focus()

func _apply_theme() -> void:
	var field_style := StyleBoxFlat.new()
	field_style.bg_color                  = Color(0.98, 0.96, 0.88, 0.92)
	field_style.border_color              = Color(0.72, 0.52, 0.18)
	field_style.border_width_top          = 2
	field_style.border_width_bottom       = 2
	field_style.border_width_left         = 2
	field_style.border_width_right        = 2
	field_style.corner_radius_top_left    = 12
	field_style.corner_radius_top_right   = 12
	field_style.corner_radius_bottom_left = 12
	field_style.corner_radius_bottom_right = 12
	field_style.content_margin_left       = 16
	field_style.content_margin_right      = 16
	field_style.content_margin_top        = 10
	field_style.content_margin_bottom     = 10

	var focus_style := field_style.duplicate() as StyleBoxFlat
	focus_style.border_color = Color(0.88, 0.65, 0.10)
	focus_style.border_width_bottom = 3

	for field: LineEdit in [
		_first_name_field, _last_name_field, _account_field,
		_password_field, _confirm_password_field,
	]:
		field.add_theme_stylebox_override("normal", field_style.duplicate())
		field.add_theme_stylebox_override("focus", focus_style.duplicate())
		field.add_theme_stylebox_override("read_only", field_style.duplicate())
		field.add_theme_font_size_override("font_size", 16)
		field.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02))
		field.add_theme_color_override("font_placeholder_color", Color(0.55, 0.40, 0.22))

	var btn_font := SystemFont.new()
	btn_font.font_names  = ["Segoe UI Variable", "Segoe UI", "Arial"]
	btn_font.font_weight = 700
	_register_btn.add_theme_font_override("font", btn_font)
	_register_btn.add_theme_font_size_override("font_size", 18)
	_register_btn.add_theme_color_override("font_color",         Color.WHITE)
	_register_btn.add_theme_color_override("font_hover_color",   Color(0.95, 0.95, 0.95))
	_register_btn.add_theme_color_override("font_pressed_color", Color(0.80, 0.80, 0.80))

	_error_label.add_theme_font_size_override("font_size", 13)
	_error_label.add_theme_color_override("font_color", Color(0.75, 0.15, 0.1))

	_login_link.add_theme_font_size_override("font_size", 13)
	_login_link.add_theme_color_override("font_color", Color(0.2, 0.45, 0.75))
	_login_link.add_theme_color_override("font_hover_color", Color(0.3, 0.55, 0.85))
	_login_link.add_theme_color_override("font_pressed_color", Color(0.15, 0.35, 0.65))

	_loading.color = Color(0, 0, 0, 0.6)
	_loading_label.add_theme_font_size_override("font_size", 18)
	_loading_label.add_theme_color_override("font_color", Color.WHITE)

func _validate_form() -> String:
	var first_name := _first_name_field.text.strip_edges()
	var last_name := _last_name_field.text.strip_edges()
	var account := _account_field.text.strip_edges()
	var password := _password_field.text
	var confirm := _confirm_password_field.text

	if first_name.is_empty():
		return "Vui lòng nhập họ."
	if last_name.is_empty():
		return "Vui lòng nhập tên."
	if account.is_empty():
		return "Vui lòng nhập tài khoản hoặc email."
	if "@" in account:
		if not account.contains(".") or account.find("@") <= 0:
			return "Email không hợp lệ."
	elif account.length() < 3:
		return "Tên đăng nhập phải có ít nhất 3 ký tự."
	if password.length() < 6:
		return "Mật khẩu phải có ít nhất 6 ký tự."
	if password != confirm:
		return "Mật khẩu xác nhận không khớp."
	return ""

func _on_register_pressed() -> void:
	var error_msg := _validate_form()
	if not error_msg.is_empty():
		_show_error(error_msg)
		return
	_set_loading(true)
	_error_label.visible = false
	UserManager.register_async(
		_first_name_field.text.strip_edges(),
		_last_name_field.text.strip_edges(),
		_account_field.text.strip_edges(),
		_password_field.text
	)

func _on_login_link_pressed() -> void:
	SceneTransition.fade_to(LOGIN_SCENE)

func _on_confirm_password_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_register_pressed()

func show_error(message: String) -> void:
	_set_loading(false)
	_show_error(message)

func on_register_success() -> void:
	_set_loading(false)
	SceneTransition.fade_to(LOGIN_SCENE)

func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true

func _set_loading(active: bool) -> void:
	_loading.visible = active
	_register_btn.disabled = active
	if active:
		_loading_label.text = "Đang đăng ký..."
