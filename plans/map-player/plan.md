# Plan: Map + Player Movement System

Status: Done
Date: 2026-05-26
Mode: Hard, --no-test

## Overview

Implement top-down 2D mobile movement for Flow Flora: GardenScene + SchoolScene với TileMapLayer, CharacterBody2D Player 4-directional animated, Dynamic virtual joystick (hold 1s → appear), và fade SceneTransition autoload.

## Phases

- [x] Phase 1: Player Scene — CharacterBody2D FLOATING, AnimatedSprite2D 4-dir, Camera2D configurable limits
- [x] Phase 2: Dynamic Joystick + HUD — hold-1s joystick bottom 40% screen, direction_changed signal, HUD CanvasLayer layer=10
- [x] Phase 3: Scenes + SceneTransition — GardenScene + SchoolScene TileMapLayer, Portal, SceneTransition autoload layer=128

## Key Rules (CLAUDE.md)

- `snake_case` variables/functions; `PascalCase` class_name
- Type hints trên TẤT CẢ parameters và return types
- Không `print()` — dùng `push_warning()` / `push_error()`
- UI updates qua signals, không gọi trực tiếp Manager→View
- `await` only (không `yield`)

## Red-Team Findings Applied

1. **Scene path allowlist** — SceneTransition.ALLOWED_SCENES validate trước `change_scene_to_file()`; push_error + abort nếu path không hợp lệ
2. **Portal double-trigger** — `_is_transitioning: bool` flag trong SceneTransition; Portal kiểm tra trước khi gọi fade_to(); flag reset sau fade-out hoặc trên mọi error path
3. **get_used_rect() empty guard** — nếu `used_rect == Rect2i()`, set camera limits về safe large default (10000) thay vì 0
4. **tile_set null guard** — null check `_tilemap.tile_set` trước khi access `.tile_size`; push_error nếu null
5. **await process_frame** — sau `change_scene_to_file()` await 2 frames (double `await get_tree().process_frame`) để đảm bảo new scene _ready() đã chạy
6. **CanvasLayer ordering** — HUD.layer = 10 (trên world, dưới fade); SceneTransition.layer = 128 (topmost)
7. **Fire-and-forget contract** — SceneTransition reset `_is_transitioning` trên TẤT CẢ exit paths (success + error)
8. **Input competition** — DynamicJoystick dùng `_unhandled_input()` + `get_viewport().set_input_as_handled()` khi consume; SwipeInteractionHandler (future) dùng `_input()` với priority cao hơn
9. **SceneTransition autoload** — thêm vào project.godot trong Phase 3; cả 4 autoloads được đăng ký
10. **Asset gate** — Phase 3 có explicit prerequisite checklist; nếu assets chưa có, dùng placeholder 1-color tile

## Asset Dependencies

Tải trước Phase 3 (hoặc dùng placeholder):
- **Kenney Tiny Town** (kenney.nl) — 16×16 tileset cho TileMapLayer
- **Kenney RPG Characters** (kenney.nl) — spritesheet 4-dir walk/idle cho Player

Placeholder thay thế: 1 solid-color 16×16 image tạo trong Godot ImageTexture, animated 2-frame ColorRect cho Player.

## Risks

- HIGH: `mouse_filter` default trên DynamicJoystick root ăn hết touch events — set `MOUSE_FILTER_IGNORE` + verify garden taps còn hoạt động
- HIGH: `InputEventScreenDrag` không có `.pressed` — touch-up PHẢI detect qua `InputEventScreenTouch` với `pressed == false`
- MEDIUM: Diagonal speed boost nếu không normalize direction trước khi scale với SPEED
- MEDIUM: Camera limits 0×0 nếu TileMapLayer chưa có tiles — guard thêm vào setup_camera_limits()
- MEDIUM: Portal double-trigger trong 0.3s fade window — `_is_transitioning` flag là lá chắn duy nhất
- LOW: Portrait lock — đặt `display/window/handheld/orientation = "portrait"` trong project.godot
