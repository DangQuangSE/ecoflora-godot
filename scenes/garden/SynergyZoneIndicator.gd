extends Node2D
class_name SynergyZoneIndicator

const _EMITTERS_PER_PLOT := 8

var _sparkle_tex: ImageTexture
var _emitters: Array[CPUParticles2D] = []


func setup(_zone_id: String, center_global: Vector2, axis_u: Vector2, plot_globals: PackedVector2Array) -> void:
	_clear_emitters()
	if _sparkle_tex == null:
		_sparkle_tex = _make_sparkle_texture()
	global_position = center_global

	if axis_u.length_squared() < 0.001 or plot_globals.is_empty():
		rotation = 0.0
		_spawn_emitter(Vector2.ZERO)
		return

	rotation = axis_u.angle()
	for gp: Vector2 in plot_globals:
		var local := (gp - center_global).rotated(-rotation)
		_spawn_emitter(local)


func _ready() -> void:
	_sparkle_tex = _make_sparkle_texture()
	set_active(false)


func set_active(active: bool, _synergy_name: String = "") -> void:
	visible = active
	for emitter: CPUParticles2D in _emitters:
		emitter.emitting = active


func _spawn_emitter(local_pos: Vector2) -> void:
	var emitter := CPUParticles2D.new()
	emitter.texture = _sparkle_tex
	emitter.position = local_pos
	emitter.amount = _EMITTERS_PER_PLOT
	emitter.lifetime = 1.7
	emitter.preprocess = 0.5
	emitter.explosiveness = 0.0
	emitter.randomness = 0.4
	emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 22.0
	emitter.direction = Vector2(0.0, -1.0)
	emitter.spread = 14.0
	emitter.gravity = Vector2.ZERO
	emitter.initial_velocity_min = 24.0
	emitter.initial_velocity_max = 42.0
	emitter.angular_velocity_min = 0.0
	emitter.angular_velocity_max = 0.0
	emitter.scale_amount_min = 1.2
	emitter.scale_amount_max = 2.8
	emitter.color = Color(0.7, 1.0, 0.8, 0.85)
	emitter.emitting = false
	add_child(emitter)
	_emitters.append(emitter)


func _clear_emitters() -> void:
	for emitter: CPUParticles2D in _emitters:
		if is_instance_valid(emitter):
			emitter.queue_free()
	_emitters.clear()


static func _make_sparkle_texture() -> ImageTexture:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2i(3, 3)
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var p := c + offset
		if p.x >= 0 and p.x < 6 and p.y >= 0 and p.y < 6:
			img.set_pixel(p.x, p.y, Color(1, 1, 1, 0.95 if offset == Vector2i.ZERO else 0.65))
	return ImageTexture.create_from_image(img)
