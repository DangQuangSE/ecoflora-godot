# Plan: Zone Unlock System

**Status:** ✅ Complete
**Date:** 2026-05-26
**Mode:** Hard | --no-test

## Overview

Thêm 2 zone đất mới (4 plot/zone) bị che bởi đám mây. Người chơi đạt level đủ → banner thông báo → tap đám mây → fade out → plots trở nên tương tác được.

## Phases

- [x] Phase 1: domain — ZoneDefinition RefCounted class
- [x] Phase 2: autoloads — ZoneManager singleton + MockGardenService zone plots + project.godot
- [x] Phase 3: scenes — CloudOverlay, UnlockBanner, GardenScene integration

## Architecture

```
domain/ZoneDefinition.gd     ← RefCounted, zone metadata thuần túy
autoloads/ZoneManager.gd     ← Node singleton, zone state machine, signals
services/MockGardenService   ← thêm 8 zone plots (plot_8 → plot_15)
autoloads/ZoneManager.gd     ← Node singleton, zone state machine, signals
scenes/garden/CloudOverlay   ← Node2D + ColorRect, tap to unlock, fade out
scenes/garden/UnlockBanner   ← CanvasLayer layer=11, notification center screen
scenes/garden/GardenScene    ← spawn CloudOverlay sau khi spawn plots
```

## Signal Chain

```
UserManager.level_up → ZoneManager._on_level_up
  → zone_notification(zone_id) → GardenScene → UnlockBanner.show()
                               → CloudOverlay._on_notified() → pulse anim

Player tap cloud → ZoneManager.request_unlock(zone_id)
  → zone_unlocked(zone_id) → CloudOverlay._on_unlocked() → fade 0.6s → queue_free()
```

## Risks

- **CRITICAL**: `CloudOverlay.setup(zone_id)` phải gọi TRƯỚC `add_child()` — tránh signal-before-ready race
- **HIGH**: ZoneManager phải đăng ký SAU UserManager trong project.godot
- **MEDIUM**: CloudOverlay ColorRect mouse_filter=STOP phải đặt đúng để chặn input xuống plots
- **MEDIUM**: Plot.gd KHÔNG bị thay đổi — zone membership chỉ ở ZoneDefinition
- **LOW**: P2 pulse animation — dùng AnimationPlayer keyframe trên ColorRect modulate
- **LOW (NOTED)**: Nếu 1 lần harvest nhảy qua cả Lv3 lẫn Lv6 cùng lúc, `zone_notification` emit 2 lần liên tiếp. `_active_banner` cap chỉ show banner đầu tiên; zone_2 notification bị drop. Chấp nhận cho MVP.

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-05-27 (finalized)
**Phase in progress:** none
**Status:** All 3 phases complete and finalized

### Decisions made this session
- `plot_ids: Array[String]` thay vì int index để khớp với string ID scheme của GardenManager
- Pulse animation dùng Tween (không cần AnimationPlayer)
- InteractionManager KHÔNG bị thay đổi — block hoàn toàn qua ColorRect mouse_filter=STOP
- ZoneManager đăng ký sau UserManager trong project.godot
- CloudOverlay dùng `_rect.gui_input` signal (không dùng `_input()`)
- `_active_banner` cap để tránh orphaned banner nodes

### Next immediate action
Code review → Step 5 finalize
