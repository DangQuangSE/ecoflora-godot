class_name Player
extends CharacterBody2D

@export var speed: float = 200.0
@export var camera_zoom: float = 1.0
@export var sprite_scale: float = 1.0

var move_direction: Vector2 = Vector2.ZERO
var _last_facing: String = "down"

var _footstep_player: AudioStreamPlayer2D
var _footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.35

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	
	_footstep_player = AudioStreamPlayer2D.new()
	_footstep_player.bus = "Master"
	add_child(_footstep_player)
	if AudioManager.get_footstep_stream():
		_footstep_player.stream = AudioManager.get_footstep_stream()

func set_move_direction(dir: Vector2) -> void:
	move_direction = dir

func setup_camera_limits(used_rect: Rect2i, tile_size: Vector2i) -> void:
	if used_rect == Rect2i():
		_camera.limit_left   = -100000
		_camera.limit_top    = -100000
		_camera.limit_right  = 100000
		_camera.limit_bottom = 100000
		push_warning("Player.setup_camera_limits: used_rect is empty, using defaults")
		return
	_camera.limit_left   = used_rect.position.x * tile_size.x
	_camera.limit_top    = used_rect.position.y * tile_size.y
	_camera.limit_right  = used_rect.end.x * tile_size.x
	_camera.limit_bottom = used_rect.end.y * tile_size.y

func _physics_process(delta: float) -> void:
	velocity = move_direction.normalized() * speed if move_direction.length() > 0.1 else Vector2.ZERO
	move_and_slide()
	_update_animation()
	_handle_footsteps(delta)

func _update_animation() -> void:
	if move_direction.length() < 0.1:
		var idle := "idle_down" if _last_facing != "up" else "idle_up"
		if _sprite.animation != idle:
			_sprite.play(idle)
		return
	var angle := move_direction.angle()
	if abs(angle) < PI / 4.0:
		_last_facing = "right"
		_sprite.play("walk_right")
	elif abs(angle) > 3.0 * PI / 4.0:
		_last_facing = "left"
		_sprite.play("walk_left")
	elif angle > 0.0:
		_last_facing = "down"
		_sprite.play("walk_down")
	else:
		_last_facing = "up"
		_sprite.play("walk_up")

func _handle_footsteps(delta: float) -> void:
	if velocity.length() > 10.0:
		_footstep_timer += delta
		if _footstep_timer >= FOOTSTEP_INTERVAL:
			_play_footstep_sound()
			_footstep_timer = 0.0
	else:
		_footstep_timer = FOOTSTEP_INTERVAL - 0.05

func _play_footstep_sound() -> void:
	if _footstep_player and _footstep_player.stream:
		_footstep_player.pitch_scale = randf_range(0.85, 1.15)
		_footstep_player.volume_db = 5
		_footstep_player.play()
