class_name Player
extends CharacterBody2D

const _CHARACTER_FRAME_PATHS: Array[String] = [
	"res://assets/characters/char_0.tres",
	"res://assets/characters/char_1.tres",
]

@export var speed: float = 200.0
@export var camera_zoom: float = 1.0
@export var sprite_scale: float = 0.4
@export var movement_bounds_margin: Vector2 = Vector2(8.0, 8.0)

var move_direction: Vector2 = Vector2.ZERO
var _last_facing: String = "down"
var _movement_bounds: Rect2 = Rect2()

var _footstep_player: AudioStreamPlayer2D

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	_camera.zoom = Vector2(camera_zoom, camera_zoom)
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	if UserManager.has_method("get_character_index"):
		set_character(UserManager.get_character_index())
	if not UserManager.character_changed.is_connected(set_character):
		UserManager.character_changed.connect(set_character)

	_footstep_player = AudioStreamPlayer2D.new()
	_footstep_player.bus = "Master"
	add_child(_footstep_player)
	var stream := AudioManager.get_footstep_stream()
	if stream:
		_footstep_player.stream = stream
		_footstep_player.volume_db = AudioManager.get_footstep_volume_db()
	AudioManager.volume_settings_changed.connect(_on_audio_volume_changed)

func _exit_tree() -> void:
	if UserManager.character_changed.is_connected(set_character):
		UserManager.character_changed.disconnect(set_character)
	if AudioManager.volume_settings_changed.is_connected(_on_audio_volume_changed):
		AudioManager.volume_settings_changed.disconnect(_on_audio_volume_changed)

func set_character(idx: int) -> void:
	var clamped := clampi(idx, 0, _CHARACTER_FRAME_PATHS.size() - 1)
	var path: String = _CHARACTER_FRAME_PATHS[clamped]
	if not ResourceLoader.exists(path):
		return
	_sprite.sprite_frames = load(path)
	if not _sprite.sprite_frames.has_animation(_sprite.animation):
		_sprite.play("idle_down")

func set_move_direction(dir: Vector2) -> void:
	move_direction = dir

func set_movement_bounds(bounds: Rect2) -> void:
	_movement_bounds = bounds

func setup_camera_world_limits(bounds: Rect2) -> void:
	if bounds == Rect2():
		_camera.limit_left   = -100000
		_camera.limit_top    = -100000
		_camera.limit_right  = 100000
		_camera.limit_bottom = 100000
		push_warning("Player.setup_camera_world_limits: bounds is empty, using defaults")
		return
	_camera.limit_left   = int(bounds.position.x)
	_camera.limit_top    = int(bounds.position.y)
	_camera.limit_right  = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)

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

func _physics_process(_delta: float) -> void:
	var keyboard_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard_dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard_dir.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard_dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard_dir.x += 1.0

	var dir := move_direction
	if keyboard_dir != Vector2.ZERO:
		dir = keyboard_dir.normalized()

	velocity = dir * speed if dir.length() > 0.1 else Vector2.ZERO
	move_and_slide()
	_clamp_to_movement_bounds()
	_update_animation(dir)
	_handle_footsteps()

func _clamp_to_movement_bounds() -> void:
	if _movement_bounds == Rect2():
		return
	var min_pos := _movement_bounds.position + movement_bounds_margin
	var max_pos := _movement_bounds.end - movement_bounds_margin
	global_position = Vector2(
		clampf(global_position.x, min_pos.x, max_pos.x),
		clampf(global_position.y, min_pos.y, max_pos.y)
	)

func _update_animation(dir: Vector2) -> void:
	if dir.length() < 0.1:
		var idle := "idle_down" if _last_facing != "up" else "idle_up"
		if _sprite.animation != idle:
			_sprite.play(idle)
		return
	var angle := dir.angle()
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

func _handle_footsteps() -> void:
	if _footstep_player == null or _footstep_player.stream == null:
		return

	var is_moving := velocity.length() > 10.0
	if is_moving:
		if not _footstep_player.playing:
			_footstep_player.play()
	elif _footstep_player.playing:
		_footstep_player.stop()


func _on_audio_volume_changed() -> void:
	if _footstep_player != null:
		_footstep_player.volume_db = AudioManager.get_footstep_volume_db()
