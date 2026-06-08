class_name PrimaryButton
extends Button

func _ready() -> void:
	# Tự động gán global theme nếu chưa có theme cụ thể nào được set
	if theme == null:
		var theme_manager := get_node_or_null("/root/ThemeManager")
		if theme_manager:
			theme = theme_manager.get_global_theme()
		else:
			theme = load("res://themes/GlobalTheme.tres") as Theme

	# Set pivot_offset về tâm để hiệu ứng zoom/rotate hoạt động đúng
	pivot_offset = size / 2.0
	resized.connect(func() -> void:
		pivot_offset = size / 2.0
	)
	
	# Kết nối tín hiệu cho micro-interactions
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)

func _on_mouse_entered() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.15)

func _on_mouse_exited() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)

func _on_button_down() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.08)

func _on_button_up() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hovered():
		tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.1)
	else:
		tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15)
