extends Control

signal login_requested(account: String, password: String)

@onready var _username_field: LineEdit  = $VBox/Card/Margin/Inner/UsernameField
@onready var _password_field: LineEdit  = $VBox/Card/Margin/Inner/PasswordField
@onready var _login_btn: Button         = $VBox/Card/Margin/Inner/LoginBtn
@onready var _offline_btn: Button       = $VBox/Card/Margin/Inner/OfflineBtn
@onready var _error_label: Label        = $VBox/Card/Margin/Inner/ErrorLabel
@onready var _loading: ColorRect        = $LoadingOverlay
@onready var _loading_label: Label      = $LoadingOverlay/LoadingLabel

const GARDEN_SCENE := "res://scenes/garden/GardenScene.tscn"

func _ready() -> void:
	_apply_theme()
	_error_label.visible = false
	_loading.visible = false
	_login_btn.pressed.connect(_on_login_pressed)
	_offline_btn.pressed.connect(_on_offline_pressed)
	_password_field.gui_input.connect(_on_password_gui_input)

	# Wire UserManager auth signals
	UserManager.login_succeeded.connect(on_login_success)
	UserManager.login_failed.connect(show_error)

	# Auto-skip login if mock mode or already logged in
	if UserManager.is_logged_in():
		SceneTransition.fade_to(GARDEN_SCENE)
		return

	_username_field.grab_focus()

func _apply_theme() -> void:
	# Background
	var bg: ColorRect = $Background
	bg.color = Color(0.08, 0.16, 0.10)

	# Title
	var title: Label = $VBox/LogoSection/TitleLabel
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.98, 0.75))

	var tagline: Label = $VBox/LogoSection/TaglineLabel
	tagline.add_theme_font_size_override("font_size", 15)
	tagline.add_theme_color_override("font_color", Color(0.55, 0.80, 0.50))

	# Card background
	var card: PanelContainer = $VBox/Card
	var card_style := StyleBoxFlat.new()
	card_style.bg_color        = Color(0.97, 0.99, 0.96)
	card_style.corner_radius_top_left     = 24
	card_style.corner_radius_top_right    = 24
	card_style.corner_radius_bottom_left  = 24
	card_style.corner_radius_bottom_right = 24
	card_style.shadow_color   = Color(0, 0, 0, 0.25)
	card_style.shadow_size    = 12
	card_style.shadow_offset  = Vector2(0, 4)
	card.add_theme_stylebox_override("panel", card_style)

	# Welcome label
	var welcome: Label = $VBox/Card/Margin/Inner/WelcomeLabel
	welcome.add_theme_font_size_override("font_size", 22)
	welcome.add_theme_color_override("font_color", Color(0.15, 0.28, 0.15))

	# Fields common style
	var field_style := StyleBoxFlat.new()
	field_style.bg_color              = Color(0.94, 0.98, 0.93)
	field_style.border_color          = Color(0.60, 0.85, 0.55)
	field_style.border_width_bottom   = 2
	field_style.border_width_left     = 1
	field_style.border_width_right    = 1
	field_style.border_width_top      = 1
	field_style.corner_radius_top_left     = 10
	field_style.corner_radius_top_right    = 10
	field_style.corner_radius_bottom_left  = 10
	field_style.corner_radius_bottom_right = 10
	field_style.content_margin_left   = 16
	field_style.content_margin_right  = 16
	field_style.content_margin_top    = 12
	field_style.content_margin_bottom = 12

	for field in [_username_field, _password_field]:
		field.add_theme_stylebox_override("normal", field_style.duplicate())
		field.add_theme_stylebox_override("focus", field_style.duplicate())
		field.add_theme_font_size_override("font_size", 16)

	# Login button
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.22, 0.62, 0.30)
	btn_style.corner_radius_top_left     = 12
	btn_style.corner_radius_top_right    = 12
	btn_style.corner_radius_bottom_left  = 12
	btn_style.corner_radius_bottom_right = 12
	btn_style.content_margin_top    = 16
	btn_style.content_margin_bottom = 16
	_login_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.18, 0.52, 0.26)
	_login_btn.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed := btn_style.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.15, 0.45, 0.22)
	_login_btn.add_theme_stylebox_override("pressed", btn_pressed)
	_login_btn.add_theme_font_size_override("font_size", 17)
	_login_btn.add_theme_color_override("font_color", Color.WHITE)
	_login_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	_login_btn.add_theme_color_override("font_pressed_color", Color.WHITE)

	# Offline button
	var offline_style := StyleBoxFlat.new()
	offline_style.bg_color          = Color(0, 0, 0, 0)
	offline_style.border_color      = Color(0.45, 0.70, 0.42)
	offline_style.border_width_bottom = 1
	offline_style.border_width_left  = 1
	offline_style.border_width_right  = 1
	offline_style.border_width_top   = 1
	offline_style.corner_radius_top_left     = 12
	offline_style.corner_radius_top_right    = 12
	offline_style.corner_radius_bottom_left  = 12
	offline_style.corner_radius_bottom_right = 12
	offline_style.content_margin_top    = 12
	offline_style.content_margin_bottom = 12
	_offline_btn.add_theme_stylebox_override("normal", offline_style)
	_offline_btn.add_theme_font_size_override("font_size", 15)
	_offline_btn.add_theme_color_override("font_color", Color(0.3, 0.55, 0.30))

	# Error label
	_error_label.add_theme_font_size_override("font_size", 13)
	_error_label.add_theme_color_override("font_color", Color(0.85, 0.25, 0.20))

	# Loading overlay
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
	_error_label.visible = false
	login_requested.emit(account, password)
	UserManager.login_async(account, password)

func _on_offline_pressed() -> void:
	SceneTransition.fade_to(GARDEN_SCENE)

func _on_password_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		_on_login_pressed()

func show_error(message: String) -> void:
	_set_loading(false)
	_show_error(message)

func on_login_success() -> void:
	_loading_label.text = "Đang tải..."
	SceneTransition.fade_to(GARDEN_SCENE)

func _show_error(msg: String) -> void:
	_error_label.text = msg
	_error_label.visible = true

func _set_loading(active: bool) -> void:
	_loading.visible = active
	_login_btn.disabled = active
	_offline_btn.disabled = active
	if active:
		_loading_label.text = "Đang đăng nhập..."
