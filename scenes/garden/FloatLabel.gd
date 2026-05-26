class_name FloatLabel
extends Node2D

func play(text_val: String) -> void:
	var lbl := Label.new()
	lbl.text = text_val
	lbl.add_theme_color_override("font_color", Color(1, 0.88, 0.1, 1))
	lbl.add_theme_color_override("font_shadow_color", Color(0.05, 0.05, 0.05, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-24, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 55.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.25)
	await tween.finished
	queue_free()
