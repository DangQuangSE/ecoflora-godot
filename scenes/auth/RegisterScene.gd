extends Control

const LOGIN_SCENE := "res://scenes/auth/LoginScene.tscn"
const GARDEN_SCENE := "res://scenes/garden/GardenScene.tscn"
const LOGO_TOP_Y := 205.0

@onready var _first_name_input: AuthInput = $RegisterFrame/FormArea/FormContent/NameRow/FirstNameInput
@onready var _last_name_input: AuthInput = $RegisterFrame/FormArea/FormContent/NameRow/LastNameInput
@onready var _account_input: AuthInput = $RegisterFrame/FormArea/FormContent/AccountInput
@onready var _password_input: AuthInput = $RegisterFrame/FormArea/FormContent/PasswordInput
@onready var _confirm_password_input: AuthInput = $RegisterFrame/FormArea/FormContent/ConfirmPasswordInput
@onready var _confirm_password_field: LineEdit = _confirm_password_input.get_line_edit()
@onready var _register_btn: Button = $RegisterFrame/FormArea/FormContent/RegisterBtnMargin/RegisterBtn
@onready var _login_link: Button = $RegisterFrame/FormArea/FormContent/LoginLink
@onready var _error_label: Label = $RegisterFrame/FormArea/FormContent/ErrorLabel
@onready var _loading: ColorRect = $LoadingOverlay
@onready var _loading_label: Label = $LoadingOverlay/LoadingLabel
@onready var _logo: Sprite2D = $Logo

func _ready() -> void:
	SceneTransition.force_clear()
	WeatherManager.set_overlay_visible(false)
	_apply_theme()
	_error_label.visible = false
	_loading.visible = false
	_register_btn.pressed.connect(_on_register_pressed)
	_login_link.pressed.connect(_on_login_link_pressed)
	_confirm_password_field.gui_input.connect(_on_confirm_password_gui_input)
	resized.connect(_layout_logo)
	_layout_logo()

	UserManager.register_succeeded.connect(on_register_success)
	UserManager.register_failed.connect(show_error)

	if UserManager.is_logged_in():
		if await UserManager.resume_session_async():
			SceneTransition.fade_to(GARDEN_SCENE)
		return

	AudioManager.play_bgm("res://sounds/lobby_v2.mp3")

	_first_name_input.focus_field()

func _apply_theme() -> void:
	_error_label.add_theme_font_size_override("font_size", 14)
	_error_label.add_theme_color_override("font_color", Color(0.75, 0.15, 0.1))

	_login_link.add_theme_font_size_override("font_size", 14)
	_login_link.add_theme_color_override("font_color", Color(0.2, 0.45, 0.75))
	_login_link.add_theme_color_override("font_hover_color", Color(0.3, 0.55, 0.85))
	_login_link.add_theme_color_override("font_pressed_color", Color(0.15, 0.35, 0.65))

	_loading.color = Color(0, 0, 0, 0.6)
	_loading_label.add_theme_font_size_override("font_size", 19)
	_loading_label.add_theme_color_override("font_color", Color.WHITE)

func _validate_form() -> String:
	var first_name := _first_name_input.strip_edges()
	var last_name := _last_name_input.strip_edges()
	var account := _account_input.strip_edges()
	var password := _password_input.text
	var confirm := _confirm_password_input.text

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
		_first_name_input.strip_edges(),
		_last_name_input.strip_edges(),
		_account_input.strip_edges(),
		_password_input.text
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
	_error_label.visible = false
	Toast.show_message(self, msg, 2.4)

func _set_loading(active: bool) -> void:
	_loading.visible = false
	_register_btn.disabled = active

func _layout_logo() -> void:
	_logo.position.x = size.x * 0.5
	_logo.position.y = LOGO_TOP_Y
