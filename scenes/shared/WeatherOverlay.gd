class_name WeatherOverlay
extends CanvasLayer

const TRANSITION_SEC := 1.2

const SUNBEAM_SHADER_CODE := """
shader_type canvas_item;

uniform float speed : hint_range(0.0, 5.0) = 0.3;
uniform float ray_density : hint_range(1.0, 50.0) = 10.0;
uniform float ray_intensity : hint_range(0.0, 1.0) = 0.12;
uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.7, 1.0);

void fragment() {
	vec2 uv = UV;
	float angle = 0.6;
	float coord = (uv.x * cos(angle) - uv.y * sin(angle)) * ray_density;
	
	float ray = sin(coord - TIME * speed) * 0.5 + 0.5;
	ray += sin(coord * 1.5 + TIME * speed * 0.7) * 0.5 + 0.5;
	ray /= 2.0;
	ray = pow(ray, 4.0);
	
	float fade = uv.y * (1.0 - uv.y) * 4.0;
	
	COLOR = vec4(ray_color.rgb, ray * ray_intensity * fade * ray_color.a);
}
"""

@onready var _clouds: CPUParticles2D = $CloudParticles
@onready var _sunbeams: ColorRect = $SunBeamOverlay
@onready var _pollen: CPUParticles2D = $PollenParticles
@onready var _wind: CPUParticles2D = $WindParticles
@onready var _rain: CPUParticles2D = $RainParticles
@onready var _splashes: CPUParticles2D = $SplashParticles
@onready var _day_night: ColorRect = $DayNightOverlay
@onready var _lightning_overlay: ColorRect = $LightningOverlay

var _tween: Tween = null
var _lightning_timer: Timer = null

func _ready() -> void:
	_generate_textures()
	_init_shader()
	
	# Adapt sizes dynamically
	_on_viewport_size_changed()
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var width: float = viewport_size.x
	var height: float = viewport_size.y

	# Anchor overlays to full rect dynamically
	for rect in [_sunbeams, _day_night, _lightning_overlay]:
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.offset_left = 0
		rect.offset_top = 0
		rect.offset_right = 0
		rect.offset_bottom = 0

	# Align particle systems based on size
	_clouds.position = Vector2(width / 2.0, height / 2.0)
	_clouds.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_clouds.emission_rect_extents = Vector2(width / 2.0 + 100, height / 2.0)

	_pollen.position = Vector2(width / 2.0, height / 2.0)
	_pollen.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_pollen.emission_rect_extents = Vector2(width / 2.0, height / 2.0)

	_wind.position = Vector2(-50, height / 2.0)
	_wind.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_wind.emission_rect_extents = Vector2(1, height / 2.0)

	_rain.position = Vector2(width / 2.0, -30)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(width / 2.0 + 150, 1)

	_splashes.position = Vector2(width / 2.0, height - 10)
	_splashes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_splashes.emission_rect_extents = Vector2(width / 2.0, 10)

func _init_shader() -> void:
	var shader := Shader.new()
	shader.code = SUNBEAM_SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_sunbeams.material = mat

func _generate_textures() -> void:
	# 1. Raindrop: vertical soft capsule
	var rain_img := Image.create(4, 20, false, Image.FORMAT_RGBA8)
	for y in range(20):
		var t := float(y) / 19.0
		var alpha: float = sin(t * PI) * 0.95
		for x in range(4):
			rain_img.set_pixel(x, y, Color(1, 1, 1, alpha))
	_rain.texture = ImageTexture.create_from_image(rain_img)

	# 2. Splash: circular impact splatter
	var splash_img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	var sc := Vector2(3, 3)
	for y in range(6):
		for x in range(6):
			var d := sc.distance_to(Vector2(x, y))
			var alpha: float = clamp(1.0 - d / 3.0, 0.0, 1.0)
			splash_img.set_pixel(x, y, Color(1, 1, 1, alpha * 0.9))
	_splashes.texture = ImageTexture.create_from_image(splash_img)

	# 3. Pollen: tiny soft glowing orb
	var pollen_img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	var pc := Vector2(4, 4)
	for y in range(8):
		for x in range(8):
			var d := pc.distance_to(Vector2(x, y))
			var alpha: float = clamp(1.0 - d / 4.0, 0.0, 1.0)
			alpha = alpha * alpha
			pollen_img.set_pixel(x, y, Color(1, 1, 1, alpha * 0.85))
	_pollen.texture = ImageTexture.create_from_image(pollen_img)

	# 4. Leaf: simple biological pointy lens
	var leaf_size := 16
	var leaf_img := Image.create(leaf_size, leaf_size, false, Image.FORMAT_RGBA8)
	for y in range(leaf_size):
		for x in range(leaf_size):
			var px := (float(x) / (leaf_size - 1)) * 2.0 - 1.0
			var py := (float(y) / (leaf_size - 1)) * 2.0 - 1.0
			var width_bound := 0.5 * (1.0 - py * py)
			if abs(px) < width_bound:
				leaf_img.set_pixel(x, y, Color(1, 1, 1, 1))
			else:
				leaf_img.set_pixel(x, y, Color(1, 1, 1, 0))
	_wind.texture = ImageTexture.create_from_image(leaf_img)

	# 5. Cloud/Fog: stylized cluster of soft fluffy circles
	var cloud_size := 128
	var cloud_img := Image.create(cloud_size, cloud_size, false, Image.FORMAT_RGBA8)
	var centers := [
		Vector2(64, 68),
		Vector2(40, 72),
		Vector2(88, 72),
		Vector2(64, 48),
		Vector2(48, 56),
		Vector2(80, 56)
	]
	var radiuses := [
		32.0,
		24.0,
		24.0,
		28.0,
		22.0,
		22.0
	]
	for y in range(cloud_size):
		for x in range(cloud_size):
			var max_alpha: float = 0.0
			var p := Vector2(x, y)
			for i in range(centers.size()):
				var d := p.distance_to(centers[i])
				if d < radiuses[i]:
					var a: float = 1.0 - (d / radiuses[i])
					a = pow(a, 1.8)
					if a > max_alpha:
						max_alpha = a
			cloud_img.set_pixel(x, y, Color(1, 1, 1, max_alpha))
	_clouds.texture = ImageTexture.create_from_image(cloud_img)

func apply_state(state: WeatherState) -> void:
	if state == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	
	_tween = create_tween().set_parallel(true)
	
	# Stop storm lightning overlay unless we are in STORM state
	if state.condition != WeatherState.Condition.STORM:
		_stop_lightning()

	match state.condition:
		WeatherState.Condition.SUNNY:
			_transition_overlay(Color(0.95, 0.85, 0.7, 0.03 if state.is_day else 0.55))
			_transition_sunbeams(state.is_day)
			_transition_particles(_pollen, true, 0.7)
			_transition_particles(_clouds, false)
			_transition_particles(_wind, false)
			_transition_particles(_rain, false)
			_transition_particles(_splashes, false)

		WeatherState.Condition.CLOUDY:
			var bg_color := Color(0.24, 0.26, 0.32, 0.32 if state.is_day else 0.65)
			_transition_overlay(bg_color)
			_transition_sunbeams(false)
			_transition_particles(_pollen, false)
			_transition_particles(_clouds, true, 1.0)
			
			# Cloudy has a very gentle leaf breeze
			_wind.direction = Vector2(1, 0.1)
			_wind.speed_scale = 0.5
			_wind.color = Color(0.4, 0.7, 0.3, 0.35) # semi-opaque green leaves
			_transition_particles(_wind, true, 0.3)
			
			_transition_particles(_rain, false)
			_transition_particles(_splashes, false)

		WeatherState.Condition.RAINY:
			var bg_color := Color(0.16, 0.2, 0.28, 0.4 if state.is_day else 0.7)
			_transition_overlay(bg_color)
			_transition_sunbeams(false)
			_transition_particles(_pollen, false)
			_transition_particles(_clouds, true, 0.8)
			
			# Moderate wind blowing leaves
			_wind.direction = Vector2(1, 0.3)
			_wind.speed_scale = 1.0
			_wind.color = Color(0.35, 0.65, 0.3, 0.6)
			_transition_particles(_wind, true, 0.6)
			
			# Angled rain with high particle density
			_rain.amount = 350
			_splashes.amount = 180
			_rain.direction = Vector2(0.15, 1.0)
			_rain.speed_scale = 1.0
			_transition_particles(_rain, true, 1.0)
			_transition_particles(_splashes, true, 0.8)

		WeatherState.Condition.STORM:
			var bg_color := Color(0.08, 0.09, 0.14, 0.6 if state.is_day else 0.8)
			_transition_overlay(bg_color)
			_transition_sunbeams(false)
			_transition_particles(_pollen, false)
			_transition_particles(_clouds, true, 1.0)
			
			# Heavy storm wind blowing leaves and debris
			_wind.direction = Vector2(1.2, 0.4)
			_wind.speed_scale = 1.8
			_wind.color = Color(0.3, 0.55, 0.25, 0.8)
			_transition_particles(_wind, true, 1.0)
			
			# Fast, heavily angled storm rain with maximum particle density
			_rain.amount = 600
			_splashes.amount = 300
			_rain.direction = Vector2(0.4, 1.0)
			_rain.speed_scale = 1.6
			_transition_particles(_rain, true, 1.0)
			_transition_particles(_splashes, true, 1.0)
			
			# Start lightning cycle
			_start_lightning()

		_:
			push_warning("WeatherOverlay.apply_state: unhandled condition %d" % state.condition)

func _transition_particles(particles: CPUParticles2D, enable: bool, target_alpha: float = 1.0) -> void:
	if enable:
		particles.emitting = true
		_tween.tween_property(particles, "self_modulate", Color(1, 1, 1, target_alpha), TRANSITION_SEC)
	else:
		_tween.tween_property(particles, "self_modulate", Color(1, 1, 1, 0.0), TRANSITION_SEC)
		# Turn off emitting after transition completes to let existing particles fade out
		_tween.tween_callback(func():
			if not enable:
				particles.emitting = false
		).set_delay(TRANSITION_SEC)

func _transition_sunbeams(enable: bool) -> void:
	if enable:
		_sunbeams.visible = true
		_tween.tween_property(_sunbeams, "self_modulate", Color(1, 1, 1, 1.0), TRANSITION_SEC)
	else:
		_tween.tween_property(_sunbeams, "self_modulate", Color(1, 1, 1, 0.0), TRANSITION_SEC)
		_tween.tween_callback(func():
			if not enable:
				_sunbeams.visible = false
		).set_delay(TRANSITION_SEC)

func _transition_overlay(target_color: Color) -> void:
	_tween.tween_property(_day_night, "color", target_color, TRANSITION_SEC) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# --- Lightning Flash System ---

func _start_lightning() -> void:
	if _lightning_timer == null:
		_lightning_timer = Timer.new()
		_lightning_timer.timeout.connect(_trigger_lightning)
		add_child(_lightning_timer)
	_schedule_next_lightning()

func _stop_lightning() -> void:
	if _lightning_timer != null:
		_lightning_timer.stop()
	_lightning_overlay.visible = false

func _schedule_next_lightning() -> void:
	if _lightning_timer != null:
		_lightning_timer.wait_time = randf_range(6.0, 16.0)
		_lightning_timer.start()

func _trigger_lightning() -> void:
	if not visible or _lightning_overlay == null:
		return
	
	_lightning_overlay.visible = true
	_lightning_overlay.color = Color(0.9, 0.94, 1.0, 0.0)
	
	# Complex cinematic double-flash sequence
	var lt := create_tween()
	# First quick strike
	lt.tween_property(_lightning_overlay, "color", Color(0.9, 0.94, 1.0, 0.7), 0.04)
	lt.tween_property(_lightning_overlay, "color", Color(0.9, 0.94, 1.0, 0.15), 0.06)
	# Second stronger spike
	lt.tween_property(_lightning_overlay, "color", Color(0.9, 0.94, 1.0, 0.9), 0.04)
	lt.tween_property(_lightning_overlay, "color", Color(0.9, 0.94, 1.0, 0.0), 0.45)
	
	# Execute screen shockwave
	_shake_screen(0.25, 12.0)
	
	lt.finished.connect(func():
		_lightning_overlay.visible = false
		_schedule_next_lightning()
	)

func _shake_screen(duration: float, intensity: float) -> void:
	var shake_tween := create_tween()
	var step_time := 0.05
	var steps := int(duration / step_time)
	for i in range(steps):
		var offset_pos := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		shake_tween.tween_property(self, "offset", offset_pos, step_time)
		intensity *= 0.75 # Exponentially decay shake power
	shake_tween.tween_property(self, "offset", Vector2.ZERO, step_time)
