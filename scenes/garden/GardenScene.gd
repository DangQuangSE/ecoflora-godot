extends Node2D

@onready var _player: Player        = $Player
@onready var _hud: HUD              = $HUD
@onready var _tilemap: TileMapLayer = $TileMapLayer

func _ready() -> void:
	_hud.joystick_direction_changed.connect(_player.set_move_direction)
	_setup_camera()

func _setup_camera() -> void:
	if not _tilemap.tile_set:
		push_error("GardenScene: TileMapLayer has no TileSet assigned")
		_player.setup_camera_limits(Rect2i(), Vector2i(16, 16))
		return
	var used_rect: Rect2i   = _tilemap.get_used_rect()
	var tile_size: Vector2i = _tilemap.tile_set.tile_size
	_player.setup_camera_limits(used_rect, tile_size)
