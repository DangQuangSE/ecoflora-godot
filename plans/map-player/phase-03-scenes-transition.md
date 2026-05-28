# Phase 3: Scenes + SceneTransition

## Layer
Application (`autoloads/SceneTransition.gd`) + Presentation (`scenes/`)

## Asset Gate — Prerequisite Checklist

**Kiểm tra trước khi bắt đầu Phase 3:**
- [ ] Kenney Tiny Town tileset đã download → `assets/tilesets/kenney_tiny_town/` (hoặc placeholder 1-color 16×16 PNG)
- [ ] Kenney RPG Characters spritesheet đã download → `assets/characters/` (hoặc giữ ColorRect placeholder)
- [ ] Tile size đã xác nhận (default: 16×16)
- [ ] Godot editor mở project không lỗi sau Phase 1 + 2

Nếu assets chưa có: **tạo placeholder tileset** trong Godot bằng cách tạo `Image` 16×16 solid green/blue rồi `ImageTexture.create_from_image()` — không cần file ngoài.

## Files

| File | Node Type | Layer |
|------|-----------|-------|
| `autoloads/SceneTransition.gd` | CanvasLayer (autoload) | Application |
| `scenes/shared/Portal.tscn` | Area2D (root) | Presentation |
| `scenes/shared/Portal.gd` | script | Presentation |
| `scenes/garden/GardenScene.tscn` | Node2D (root) | Presentation |
| `scenes/garden/GardenScene.gd` | script | Presentation |
| `scenes/school/SchoolScene.tscn` | Node2D (root) | Presentation |
| `scenes/school/SchoolScene.gd` | script | Presentation |
| `project.godot` (edit) | — | — |

## Spec Stories
US-01..US-07 đầy đủ

## Steps

1. Tạo `autoloads/SceneTransition.gd`. Đăng ký trong `project.godot` autoloads cùng với 3 autoloads hiện có (GardenManager, InventoryManager, InteractionManager).

2. `SceneTransition` có `ALLOWED_SCENES` const array — validate path trước mỗi `change_scene_to_file()` call.

3. Tạo `scenes/shared/Portal.tscn` (Area2D + CollisionShape2D 32×64). Portal.gd kiểm tra `SceneTransition._is_transitioning` trước khi gọi `fade_to()`.

4. Tạo `scenes/garden/GardenScene.tscn`:
   - Node2D root
   - `TileMapLayer` child (tileset placeholder hoặc Kenney) — vẽ ≥ 20×30 tiles, thêm solid border có physics collision
   - `Player` instance (từ Phase 1)
   - `HUD` instance (từ Phase 2) — CanvasLayer tự render trên world
   - `Portal` instance — positioned tại exit point, `target_scene = "res://scenes/school/SchoolScene.tscn"`

5. Viết `GardenScene.gd`: connect HUD signal → Player method, setup camera limits.

6. Mirror cho `SchoolScene.tscn` + `SchoolScene.gd` (Portal target về GardenScene, tileset màu khác).

7. Set `project.godot`:
   - `display/window/handheld/orientation = "portrait"`
   - `application/run/main_scene = "res://scenes/garden/GardenScene.tscn"`
   - Thêm SceneTransition vào autoloads

8. TileMapLayer collision: mở TileSet editor → Physics Layers → Add Layer → chọn solid border tiles → enable physics polygon. Player CharacterBody2D và Portal Area2D đều dùng collision layer 1 (default).

## Exact Code

### autoloads/SceneTransition.gd

```gdscript
extends CanvasLayer

const ALLOWED_SCENES: Array[String] = [
    "res://scenes/garden/GardenScene.tscn",
    "res://scenes/school/SchoolScene.tscn",
]

@onready var _overlay: ColorRect = $ColorRect

var _is_transitioning: bool = false

func is_transitioning() -> bool:
    return _is_transitioning

func _ready() -> void:
    layer = 128  # topmost — renders above HUD (layer=10) and everything else
    _overlay.color = Color(0.0, 0.0, 0.0, 0.0)
    _overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fade_to(scene_path: String) -> void:
    if _is_transitioning:
        return
    if scene_path not in ALLOWED_SCENES:
        push_error("SceneTransition.fade_to: path not in allowlist: %s" % scene_path)
        return
    _is_transitioning = true
    await _fade_in()
    get_tree().change_scene_to_file(scene_path)
    # Wait 2 frames: first frame processes deferred scene change,
    # second frame ensures new scene's _ready() has completed.
    await get_tree().process_frame
    await get_tree().process_frame
    await _fade_out()
    _is_transitioning = false

func _fade_in() -> void:
    var tween: Tween = create_tween()
    tween.tween_property(_overlay, "color:a", 1.0, 0.3)
    await tween.finished

func _fade_out() -> void:
    var tween: Tween = create_tween()
    tween.tween_property(_overlay, "color:a", 0.0, 0.3)
    await tween.finished
```

### scenes/shared/Portal.gd

```gdscript
class_name Portal
extends Area2D

@export var target_scene: String = ""

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
    if not (body is Player):
        return
    if target_scene.is_empty():
        push_warning("Portal: target_scene is empty")
        return
    if SceneTransition.is_transitioning():
        return
    SceneTransition.fade_to(target_scene)
```

### scenes/garden/GardenScene.gd

```gdscript
extends Node2D

@onready var _player: Player       = $Player
@onready var _hud: HUD             = $HUD
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
```

### project.godot autoloads section (thêm vào)

```ini
[autoload]
GardenManager="*res://autoloads/GardenManager.gd"
InventoryManager="*res://autoloads/InventoryManager.gd"
InteractionManager="*res://autoloads/InteractionManager.gd"
SceneTransition="*res://autoloads/SceneTransition.gd"
```

## Done When

- [ ] `SceneTransition` accessible globally (gõ `SceneTransition.` trong script không lỗi)
- [ ] GardenScene load là main scene, Player thấy được và joystick hoạt động
- [ ] Player không đi xuyên solid tiles
- [ ] Camera2D không ra ngoài bounds của TileMapLayer
- [ ] Walk vào Portal → fade đen → SchoolScene load → fade sáng
- [ ] SchoolScene Portal → fade → GardenScene (round-trip OK)
- [ ] Thử trigger Portal 2 lần liên tiếp → chỉ trigger 1 lần (double-trigger guard)
- [ ] Scene path sai (test với `"res://invalid.tscn"`) → push_error, không crash
- [ ] Portrait orientation lock hoạt động trên device/simulator
- [ ] Không có `print()` trong bất kỳ file nào của phase này
