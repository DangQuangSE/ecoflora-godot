# Spec: Map + Player Movement

**Feature:** World map với 2 scene (Garden / School) và player top-down di chuyển bằng dynamic virtual joystick
**Status:** Ready for planning
**Brainstorm:** plans/reports/260526-map-player-brainstorm.md

---

## User Stories

### P1 — Must Have (MVP demo)

| ID | Story |
|----|-------|
| US-01 | Là player, tôi mở game và thấy Garden scene với TileMap top-down, player sprite ở giữa |
| US-02 | Là player, tôi nhấn giữ ngón tay ở vùng dưới màn hình ≥ 1 giây → joystick ảo xuất hiện tại vị trí đó |
| US-03 | Là player, khi joystick xuất hiện, tôi kéo ngón tay để điều hướng → player di chuyển đúng hướng với animation 4-directional |
| US-04 | Là player, khi tôi nhấc ngón tay → joystick biến mất, player dừng lại |
| US-05 | Là player, tôi bước vào Portal → scene chuyển sang SchoolScene (có fade) |
| US-06 | Là player, trong SchoolScene tôi bước vào Portal → quay lại GardenScene |
| US-07 | Là player, player không đi xuyên tường (collision với TileMap) |

### P2 — Should Have

| ID | Story |
|----|-------|
| US-08 | Camera follow player với giới hạn bounds của scene |
| US-09 | Joystick zone chỉ nhận input ở nửa dưới màn hình, nửa trên dành cho garden interaction |
| US-10 | Player idle animation khi đứng yên |

### P3 — Nice to Have

| ID | Story |
|----|-------|
| US-11 | Transition fade (0.3s) khi chuyển scene |
| US-12 | Player shadow nhỏ dưới chân |
| US-13 | Footstep sound effect |

---

## Success Criteria

| Criterion | Measurable Target |
|-----------|------------------|
| Player movement | ≤ 8ms input lag trên Android (1 frame @ 120fps) |
| Joystick appear | Xuất hiện đúng sau 1.0s ± 0.1s hold |
| Joystick zone | Chỉ trigger khi touch Y > 60% màn hình |
| Collision | Player không overlap tile solid bất kỳ góc nào |
| Scene transition | Chuyển scene ≤ 0.5s (không tính fade) |
| Animation | 4 direction walk cycle, mỗi direction ≥ 2 frames |

---

## Architecture

```
scenes/
  garden/
    GardenScene.tscn        ← TileMap + Player spawn + Portal + GardenGrid
    GardenScene.gd
  school/
    SchoolScene.tscn        ← TileMap + Player spawn + Portal + ClassroomDoor
    SchoolScene.gd
  shared/
    Player.tscn             ← CharacterBody2D + AnimatedSprite2D + CollisionShape2D + Camera2D
    Player.gd
  hud/
    HUD.tscn                ← CanvasLayer (Joystick + Inventory button)
    HUD.gd
    DynamicJoystick.tscn    ← Control node
    DynamicJoystick.gd

assets/
  tilesets/
    kenney_tiny_town/       ← Garden tileset (CC0)
    kenney_city/            ← School tileset (CC0)
  characters/
    player_spritesheet.png  ← 4-dir walk + idle (Kenney RPG Characters or similar CC0)
```

---

## Key Design Decisions

### Dynamic Joystick — Behavior Spec

```
State machine:
  IDLE
    → touch begins in joystick_zone (Y > 60% screen): start hold_timer (1.0s)
    → touch ends before 1s: cancel timer → stay IDLE

  WAITING (hold_timer running)
    → 1s elapsed: spawn joystick at touch origin → state = ACTIVE
    → touch ends: cancel → IDLE

  ACTIVE
    → drag: compute direction vector from joystick center to finger
             normalize → apply to player velocity
             move knob sprite (clamped to radius)
    → touch ends: hide joystick → player velocity = 0 → IDLE

joystick_zone: Rect2(0, screen_height * 0.6, screen_width, screen_height * 0.4)
max_radius: 60px (canvas units)
```

### Input Zone Split

```
Screen split (portrait):
  Top 60%  → Garden interaction (SwipeInteractionHandler, tap PlotView)
  Bottom 40% → DynamicJoystick zone
```

### Player Movement

```gdscript
# CharacterBody2D
const SPEED := 120.0  # pixels/second

func _physics_process(delta: float) -> void:
    velocity = joystick_direction * SPEED
    move_and_slide()
    _update_animation()
```

### Scene Transition

```gdscript
# Via Portal (Area2D)
func _on_body_entered(body: Node) -> void:
    if body is Player:
        SceneTransition.fade_to(target_scene_path)
```

---

## Assets Checklist (trước khi cook)

- [ ] Download Kenney Tiny Town tileset → `assets/tilesets/kenney_tiny_town/`
- [ ] Download Kenney City tileset → `assets/tilesets/kenney_city/`
- [ ] Download player spritesheet (4-dir walk, CC0) → `assets/characters/`
- [ ] Xác định tile size (16px hay 32px) để config TileSet đúng

---

## Out of Scope (feature này)

- Garden plot interaction (sẽ connect sau khi player + map xong)
- Focus Mode trigger tại ClassroomDoor (spec riêng)
- NPC characters
- Day/night cycle
