extends Control

signal login_requested(account: String, password: String)

@onready var _username_field: LineEdit = $LoginFrame/FormArea/FormContent/UsernameWrapper/UsernameField
@onready var _password_field: LineEdit = $LoginFrame/FormArea/FormContent/PasswordWrapper/PasswordField
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
		SceneTransition.fade_to(GARDEN_SCENE)
		return

	var success_msg := UserManager.take_registration_success_message()
	if not success_msg.is_empty():
		_show_success(success_msg)

	_username_field.grab_focus()

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

	for field: LineEdit in [_username_field, _password_field]:
		field.add_theme_stylebox_override("normal", field_style.duplicate())
		field.add_theme_stylebox_override("focus", focus_style.duplicate())
		field.add_theme_stylebox_override("read_only", field_style.duplicate())
		field.add_theme_font_size_override("font_size", 16)
		field.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02))
		field.add_theme_color_override("font_placeholder_color", Color(0.55, 0.40, 0.22))

	var btn_font := SystemFont.new()
	btn_font.font_names  = ["Segoe UI Variable", "Segoe UI", "Arial"]
	btn_font.font_weight = 700
	_login_btn.add_theme_font_override("font", btn_font)
	_login_btn.add_theme_font_size_override("font_size", 18)
	_login_btn.add_theme_color_override("font_color",         Color.WHITE)
	_login_btn.add_theme_color_override("font_hover_color",   Color(0.95, 0.95, 0.95))
	_login_btn.add_theme_color_override("font_pressed_color", Color(0.80, 0.80, 0.80))

	_success_label.add_theme_font_size_override("font_size", 13)
	_success_label.add_theme_color_override("font_color", Color(0.1, 0.55, 0.2))

	_error_label.add_theme_font_size_override("font_size", 13)
	_error_label.add_theme_color_override("font_color", Color(0.75, 0.15, 0.1))

	_register_link.add_theme_font_size_override("font_size", 13)
	_register_link.add_theme_color_override("font_color", Color(0.2, 0.45, 0.75))
	_register_link.add_theme_color_override("font_hover_color", Color(0.3, 0.55, 0.85))
	_register_link.add_theme_color_override("font_pressed_color", Color(0.15, 0.35, 0.65))

	_loading.color = Color(0, 0, 0, 0.6)
	_loading_label.add_theme_font_size_override("font_size", 18)
	_loading_label.add_theme_color_override("font_color", Color.WHITE)

func _on_login_pressed() -> void:
	var account := _username_field.text.strip_edges()
	var password := _password_field.text
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
	_show_error(message)

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
	if active:
		_loading_label.text = "Đang đăng nhập..."
