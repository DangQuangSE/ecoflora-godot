class_name AuthInput
extends Control

@export var placeholder_text: String = "":
	set(value):
		placeholder_text = value
		if is_node_ready():
			_field.placeholder_text = value

@export var secret: bool = false:
	set(value):
		secret = value
		if is_node_ready():
			if value:
				_has_password_toggle = true
			_apply_secret_state()

var text: String:
	get:
		return _field.text if is_node_ready() else ""
	set(value):
		if is_node_ready():
			_field.text = value

var _has_password_toggle := false

@onready var _field: LineEdit = $Field
@onready var _eye_button: TextureButton = $EyeButton

const EYE_OPEN_ICON := preload("res://assets/icon/eye_open.svg")
const EYE_CLOSED_ICON := preload("res://assets/icon/eye_closed.svg")

func _ready() -> void:
	_has_password_toggle = secret
	_field.placeholder_text = placeholder_text
	_apply_secret_state()
	_eye_button.pressed.connect(_on_eye_pressed)

func get_line_edit() -> LineEdit:
	return _field

func focus_field() -> void:
	_field.grab_focus()

func strip_edges() -> String:
	return _field.text.strip_edges()

func _on_eye_pressed() -> void:
	secret = not secret
	_apply_secret_state()

func _apply_secret_state() -> void:
	_field.secret = secret
	_field.secret_character = "●"
	_eye_button.visible = _has_password_toggle
	_apply_password_padding()
	var icon := EYE_CLOSED_ICON if secret else EYE_OPEN_ICON
	_eye_button.texture_normal = icon
	_eye_button.texture_pressed = icon
	_eye_button.texture_hover = icon

func _apply_password_padding() -> void:
	for style_name in ["normal", "focus", "read_only"]:
		if not _has_password_toggle:
			_field.remove_theme_stylebox_override(style_name)
			continue
		var style := _field.get_theme_stylebox(style_name, "LineEdit").duplicate()
		if style is StyleBoxFlat:
			(style as StyleBoxFlat).content_margin_right = 56
		_field.add_theme_stylebox_override(style_name, style)
