extends Node2D
class_name SynergyZoneIndicator

@onready var _rise: CPUParticles2D = $RiseSparkles


func setup(_zone_id: String, center_global: Vector2, zone_extents: Vector2) -> void:
	global_position = center_global
	var padded := zone_extents + Vector2(36.0, 28.0)
	# Emitter sits along the bottom edge; particles drift upward only.
	_rise.position = Vector2(0.0, padded.y * 0.42)
	_rise.emission_rect_extents = Vector2(padded.x, 10.0)


func _ready() -> void:
	_rise.texture = _make_sparkle_texture()
	set_active(false)


func set_active(active: bool, _synergy_name: String = "") -> void:
	visible = active
	_rise.emitting = active


static func _make_sparkle_texture() -> ImageTexture:
	var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2i(3, 3)
	for offset: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var p := c + offset
		if p.x >= 0 and p.x < 6 and p.y >= 0 and p.y < 6:
			img.set_pixel(p.x, p.y, Color(1, 1, 1, 0.95 if offset == Vector2i.ZERO else 0.65))
	return ImageTexture.create_from_image(img)
