# Phase 1: Player Scene

## Layer
Presentation — `scenes/shared/`

## Files

| File | Node Type | Layer |
|------|-----------|-------|
| `scenes/shared/Player.tscn` | CharacterBody2D (root) | Presentation |
| `scenes/shared/Player.gd` | script | Presentation |

## Spec Stories
US-01 (Player traverses garden), US-02 (Player traverses school)

## Steps

1. Tạo thư mục `scenes/shared/`. Thêm `Player.tscn`:
   - Root: `CharacterBody2D`
   - Child: `AnimatedSprite2D` (placeholder SpriteFrames — 5 anims: `idle`, `walk_right`, `walk_left`, `walk_up`, `walk_down`, mỗi anim 1 frame ColorRect 32×32)
   - Child: `CollisionShape2D` (CapsuleShape2D, radius=12, height=20)
   - Child: `Camera2D` (enabled=true, position_smoothing_enabled=true, speed=5.0)

2. Trong Inspector của root CharacterBody2D: set `motion_mode = MOTION_MODE_FLOATING` — không có gravity, đúng cho top-down.

3. Tạo `Player.gd`, attach vào root. Implement đầy đủ theo code dưới.

4. Placeholder SpriteFrames: tạo `SpriteFrames` resource, thêm 5 animation names, mỗi animation có 1 frame là `PlaceholderTexture2D` 32×32 màu xanh. Khi có Kenney RPG Characters, import spritesheet và replace frames — không cần thay code.

## Exact Code

```gdscript
class_name Player
extends CharacterBody2D

const SPEED := 120.0

var move_direction: Vector2 = Vector2.ZERO

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
    motion_mode = MOTION_MODE_FLOATING

func set_move_direction(dir: Vector2) -> void:
    move_direction = dir

func setup_camera_limits(used_rect: Rect2i, tile_size: Vector2i) -> void:
    if used_rect == Rect2i():
        # TileMapLayer chưa có tiles — set large safe defaults
        _camera.limit_left   = -10000
        _camera.limit_top    = -10000
        _camera.limit_right  = 10000
        _camera.limit_bottom = 10000
        push_warning("Player.setup_camera_limits: used_rect is empty, using defaults")
        return
    _camera.limit_left   = used_rect.position.x * tile_size.x
    _camera.limit_top    = used_rect.position.y * tile_size.y
    _camera.limit_right  = used_rect.end.x * tile_size.x
    _camera.limit_bottom = used_rect.end.y * tile_size.y

func _physics_process(_delta: float) -> void:
    velocity = move_direction.normalized() * SPEED if move_direction.length() > 0.1 else Vector2.ZERO
    move_and_slide()
    _update_animation()

func _update_animation() -> void:
    if move_direction.length() < 0.1:
        _sprite.play("idle")
        return
    var angle := move_direction.angle()
    if abs(angle) < PI / 4.0:
        _sprite.play("walk_right")
    elif abs(angle) > 3.0 * PI / 4.0:
        _sprite.play("walk_left")
    elif angle > 0.0:
        _sprite.play("walk_down")
    else:
        _sprite.play("walk_up")
```

## Done When

- [ ] `scenes/shared/Player.tscn` mở được trong Godot editor không lỗi
- [ ] Player di chuyển đúng 120 px/s theo cardinal directions
- [ ] Diagonal KHÔNG nhanh hơn cardinal (normalized guard)
- [ ] `idle` play khi direction = Vector2.ZERO
- [ ] 4 walk animations play đúng hướng
- [ ] `setup_camera_limits()` không crash khi `used_rect == Rect2i()`
- [ ] Không có `print()` trong Player.gd
