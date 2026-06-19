extends Control

signal login_requested(account: String, password: String)

@onready var _username_input: AuthInput = $LoginFrame/FormArea/FormContent/UsernameInput
@onready var _password_input: AuthInput = $LoginFrame/FormArea/FormContent/PasswordInput
@onready var _password_field: LineEdit = _password_input.get_line_edit()
@onready var _login_btn: Button        = $LoginFrame/FormArea/FormContent/LoginBtnMargin/LoginBtn
@onready var _success_label: Label    = $LoginFrame/FormArea/FormContent/SuccessLabel
@onready var _error_label: Label       = $LoginFrame/FormArea/FormContent/ErrorLabel
@onready var _register_link: Button    = $LoginFrame/FormArea/FormContent/RegisterLink
@onready var _loading: ColorRect       = $LoadingOverlay
@onready var _loading_label: Label     = $LoadingOverlay/LoadingLabel

const GARDEN_SCENE := "res://scenes/garden/GardenScene.tscn"
const REGISTER_SCENE := "res://scenes/auth/RegisterScene.tscn"
func _ready() -> void:
	SceneTransition.force_clear()
	WeatherManager.set_overlay_visible(false)
	_apply_theme()
	_error_label.visible = false
	_success_label.visible = false
	_loading.visible = false
	_login_btn.pressed.connect(_on_login_pressed)
	_register_link.pressed.connect(_on_register_link_pressed)
	_password_field.gui_input.connect(_on_password_gui_input)

	UserManager.login_succeeded.connect(on_login_success)
	UserManager.login_failed.connect(show_error)

	if UserManager.is_logged_in():
		_set_loading(true)
		_loading_label.text = "Đang tải..."
		await UserManager.fetch_profile_async()
		SceneTransition.fade_to(GARDEN_SCENE)
		return

	AudioManager.play_bgm("res://sounds/lobby_v2.mp3")

	var success_msg := UserManager.take_registration_success_message()
	if not success_msg.is_empty():
		_show_success(success_msg)

	_username_input.focus_field()

func _apply_theme() -> void:
	_success_label.add_theme_font_size_override("font_size", 13)
	_success_label.add_theme_color_override("font_color", Color(0.1, 0.55, 0.2))

	_error_label.add_theme_font_size_override("font_size", 13)
	_error_label.add_theme_color_override("font_color", Color(0.75, 0.15, 0.1))

	_login_btn.add_theme_font_size_override("font_size", 22)

	_register_link.add_theme_font_size_override("font_size", 17)
	_register_link.add_theme_color_override("font_color", Color(0.2, 0.45, 0.75))
	_register_link.add_theme_color_override("font_hover_color", Color(0.3, 0.55, 0.85))
	_register_link.add_theme_color_override("font_pressed_color", Color(0.15, 0.35, 0.65))

	_loading.color = Color(0, 0, 0, 0.6)
	_loading_label.add_theme_font_size_override("font_size", 18)
	_loading_label.add_theme_color_override("font_color", Color.WHITE)

func _on_login_pressed() -> void:
	var account := _username_input.strip_edges()
	var password := _password_input.text
	if account.is_empty() or password.is_empty():
		_show_error("Vui lòng nhập tài khoản và mật khẩu.")
		return
	_set_loading(true)
	_success_label.visible = false
	_error_label.visible = false
	login_requested.emit(account, password)
	UserManager.login_async(account, password)

func _on_password_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_login_pressed()

func _on_register_link_pressed() -> void:
	SceneTransition.fade_to(REGISTER_SCENE)

func show_error(message: String) -> void:
	_set_loading(false)
	BaseDialog.show_alert(self, "Lỗi Đăng Nhập", message)

func on_login_success() -> void:
	_loading_label.text = "Đang tải..."
	SceneTransition.fade_to(GARDEN_SCENE)

func _show_success(msg: String) -> void:
	_error_label.visible = false
	_success_label.text = msg
	_success_label.visible = true

func _show_error(msg: String) -> void:
	_success_label.visible = false
	_error_label.text = msg
	_error_label.visible = true

func _set_loading(active: bool) -> void:
	_loading.visible = active
	_login_btn.disabled = active
