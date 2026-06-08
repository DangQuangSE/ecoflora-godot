extends CanvasLayer

# Rotation speed of the main loader asset (radians per second)
var rotation_speed: float = 3.5

var _overlay: ColorRect
var _texture_rect: TextureRect
var _loading_text_rect: TextureRect
var _load_count: int = 0
var _is_active: bool = false
var _fade_tween: Tween

# Falling leaves properties
var _leaf_container: Control
var _leaves: Array[Dictionary] = []
var _leaf_count: int = 10
var _time_passed: float = 0.0

# Screen viewport size defaults (will be updated dynamically)
var _screen_size := Vector2(720, 920)

func _ready() -> void:
	# Set a high layer so it appears on top of game UI, but below SceneTransition (128)
	layer = 120
	
	# Get display size from project settings
	_screen_size.x = ProjectSettings.get_setting("display/window/size/viewport_width")
	_screen_size.y = ProjectSettings.get_setting("display/window/size/viewport_height")
	
	# Create overlay background
	_overlay = ColorRect.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.color = Color(0.04, 0.04, 0.06, 0.0) # start transparent
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	
	# CenterContainer to center the loading sprite
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	
	# TextureRect for the loading image (flowers ring)
	_texture_rect = TextureRect.new()
	var tex := load("res://assets/loading/loading.png") as Texture2D
	if tex:
		_texture_rect.texture = tex
		_texture_rect.pivot_offset = tex.get_size() / 2.0
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_texture_rect.modulate.a = 0.0
	_texture_rect.scale = Vector2(0.28, 0.28)
	center.add_child(_texture_rect)
	
	# TextureRect for the "Đang tải..." text asset
	_loading_text_rect = TextureRect.new()
	var text_tex := load("res://assets/loading/loading-text.png") as Texture2D
	if text_tex:
		_loading_text_rect.texture = text_tex
		_loading_text_rect.pivot_offset = text_tex.get_size() / 2.0
	_loading_text_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_loading_text_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	
	# Position the text asset centered horizontally, offset below the rotating wheel
	_loading_text_rect.set_anchors_preset(Control.PRESET_CENTER)
	_loading_text_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading_text_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_loading_text_rect.offset_left = -250.0
	_loading_text_rect.offset_right = 250.0
	_loading_text_rect.offset_top = 110.0
	_loading_text_rect.offset_bottom = 170.0
	_loading_text_rect.scale = Vector2(0.28, 0.28)
	_loading_text_rect.modulate.a = 0.0
	_overlay.add_child(_loading_text_rect)
	
	# Container for leaves
	_leaf_container = Control.new()
	_leaf_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_leaf_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_leaf_container)
	
	# Initialize leaves
	var leaf_tex := load("res://assets/loading/leaf.png") as Texture2D
	if leaf_tex:
		for i in range(_leaf_count):
			var leaf_node := TextureRect.new()
			leaf_node.texture = leaf_tex
			leaf_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
			leaf_node.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			leaf_node.pivot_offset = leaf_tex.get_size() / 2.0
			leaf_node.visible = false
			_leaf_container.add_child(leaf_node)
			
			# Generate randomized leaf parameters to create organic feel
			var size_scale := randf_range(0.08, 0.18)
			var leaf_data := {
				"node": leaf_node,
				"scale": size_scale,
				"speed_y": randf_range(70.0, 150.0),
				"base_x": randf_range(0.0, _screen_size.x),
				"y": randf_range(0.0, _screen_size.y), # initial scatter all over screen
				"sway_amplitude": randf_range(20.0, 60.0),
				"sway_frequency": randf_range(1.0, 2.5),
				"rot_speed": randf_range(-1.2, 1.2),
				"time_offset": randf_range(0.0, 10.0),
				# Opaque value based on size to simulate depth (smaller = further = dimmer)
				"target_alpha": lerpf(0.4, 0.85, (size_scale - 0.08) / 0.10)
			}
			# Apply scale and pivot offset
			leaf_node.scale = Vector2(size_scale, size_scale)
			_leaves.append(leaf_data)
			
	_overlay.visible = false
	set_process(false)

func _process(delta: float) -> void:
	_time_passed += delta
	if _texture_rect and _texture_rect.visible:
		_texture_rect.rotation += rotation_speed * delta
		
	# Animate leaves falling
	var leaf_tex := load("res://assets/loading/leaf.png") as Texture2D
	var tex_size := leaf_tex.get_size() if leaf_tex else Vector2.ZERO
	
	for leaf in _leaves:
		var node: TextureRect = leaf["node"]
		if node.visible:
			# Update position
			leaf["y"] = float(leaf["y"]) + float(leaf["speed_y"]) * delta
			
			# If fell off bottom, wrap back to top
			if float(leaf["y"]) > _screen_size.y + 50.0:
				leaf["y"] = -50.0
				leaf["base_x"] = randf_range(0.0, _screen_size.x)
				leaf["speed_y"] = randf_range(70.0, 150.0)
				leaf["sway_amplitude"] = randf_range(20.0, 60.0)
				leaf["sway_frequency"] = randf_range(1.0, 2.5)
				leaf["rot_speed"] = randf_range(-1.2, 1.2)
				
			var t: float = _time_passed + float(leaf["time_offset"])
			# sway horizontally
			var x: float = float(leaf["base_x"]) + sin(t * float(leaf["sway_frequency"])) * float(leaf["sway_amplitude"])
			
			# Apply rotation sway + continuous rotation
			node.rotation = sin(t * 1.5) * 0.5 + t * float(leaf["rot_speed"])
			
			# Center position on computed coordinate
			node.position = Vector2(x, float(leaf["y"])) - (tex_size * node.scale.x) / 2.0

func show_loading() -> void:
	_load_count += 1
	if _is_active:
		return
		
	_is_active = true
	_overlay.visible = true
	set_process(true)
	
	# Update screen size just in case the window was resized
	_screen_size = _overlay.size
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	# Reset animations state before starting
	if _texture_rect:
		_texture_rect.modulate.a = 0.0
		_texture_rect.scale = Vector2(0.28, 0.28)
		
	if _loading_text_rect:
		_loading_text_rect.modulate.a = 0.0
		_loading_text_rect.scale = Vector2(0.28, 0.28)
		
	# Distribute leaves randomly across screen for starting
	for leaf in _leaves:
		var node: TextureRect = leaf["node"]
		node.visible = true
		node.modulate.a = 0.0
		node.scale = Vector2(float(leaf["scale"]) * 0.7, float(leaf["scale"]) * 0.7)
		leaf["y"] = randf_range(0.0, _screen_size.y)
		leaf["base_x"] = randf_range(0.0, _screen_size.x)
		
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_overlay, "color:a", 0.65, 0.25)
	if _texture_rect:
		_fade_tween.tween_property(_texture_rect, "modulate:a", 1.0, 0.2)
		_fade_tween.tween_property(_texture_rect, "scale", Vector2(0.33, 0.33), 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
	if _loading_text_rect:
		_fade_tween.tween_property(_loading_text_rect, "modulate:a", 1.0, 0.2)
		_fade_tween.tween_property(_loading_text_rect, "scale", Vector2(0.33, 0.33), 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
	# Tween leaves in
	for leaf in _leaves:
		var node: TextureRect = leaf["node"]
		_fade_tween.tween_property(node, "modulate:a", float(leaf["target_alpha"]), 0.2)
		_fade_tween.tween_property(node, "scale", Vector2(float(leaf["scale"]), float(leaf["scale"])), 0.25)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_loading() -> void:
	_load_count = max(0, _load_count - 1)
	if _load_count > 0 or not _is_active:
		return
		
	_is_active = false
	set_process(false)
	
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(_overlay, "color:a", 0.0, 0.25)
	if _texture_rect:
		_fade_tween.tween_property(_texture_rect, "modulate:a", 0.0, 0.2)
		_fade_tween.tween_property(_texture_rect, "scale", Vector2(0.28, 0.28), 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			
	if _loading_text_rect:
		_fade_tween.tween_property(_loading_text_rect, "modulate:a", 0.0, 0.2)
		_fade_tween.tween_property(_loading_text_rect, "scale", Vector2(0.28, 0.28), 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			
	# Tween leaves out
	for leaf in _leaves:
		var node: TextureRect = leaf["node"]
		_fade_tween.tween_property(node, "modulate:a", 0.0, 0.2)
		_fade_tween.tween_property(node, "scale", Vector2(float(leaf["scale"]) * 0.7, float(leaf["scale"]) * 0.7), 0.2)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			
	_fade_tween.chain().tween_callback(func() -> void:
		if not _is_active:
			_overlay.visible = false
			for leaf in _leaves:
				(leaf["node"] as TextureRect).visible = false
	)
