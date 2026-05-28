# Plan: User XP + Leveling System

**Status:** ✅ Done
**Date:** 2026-05-26
**Mode:** Hard | --no-test

## Overview

Thêm hệ thống XP và Level cho người chơi. Thu hoạch hoa → cộng XP → level up với animation. Tap avatar → xem profile card.

## Phases

- [x] Phase 1: domain — UserProfile RefCounted với XP math + multi-level-up loop
- [x] Phase 2: autoload — UserManager singleton, kết nối harvest_completed, emit signals
- [x] Phase 3: scenes — UserHUD widget trong HUD, UserProfileCard slide-up, level-up animation

## Architecture

```
domain/UserProfile.gd       ← RefCounted, XP math thuần túy
autoloads/UserManager.gd    ← Node singleton, wires harvest_completed, emits signals
scenes/hud/UserHUD.tscn/gd  ← Control widget top-left, connects UserManager signals
scenes/hud/UserProfileCard  ← CanvasLayer layer=9, slide-up stats card
```

## Risks

- UserManager phải được đăng ký trong project.godot SAU GardenManager để _ready() kết nối thành công
- harvest_completed emit trong khi is_pending_sync=true — UserManager không được call lại GardenManager từ handler này
- Multi-level-up nhanh: dùng is_animating_level_up flag để tránh Tween bị ghi đè giữa chừng
- Float label "+XP" trong HUD phải là Control-based (Label + Tween trên position), KHÔNG dùng FloatLabel.gd (world-space Node2D)
- UserProfileCard (layer=9) và FlowerInfoCard (layer=8): có thể mở cùng lúc (quyết định của user)

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-05-26 21:10
**Phase in progress:** phase-03-hud-scenes
**Status:** Phase 1+2 hoàn thành, chuẩn bị implement HUD scenes

### Decisions made this session
- add_xp() dùng while-loop với carry-over XP (không reset về 0 khi level up)
- XP table keyed on full product_id string, không parse
- UserManager đăng ký SAU GardenManager trong project.godot
- Cả 2 card (FlowerInfoCard + UserProfileCard) có thể mở cùng lúc

### Next immediate action
Tạo UserHUD.tscn, UserHUD.gd, UserProfileCard.tscn, UserProfileCard.gd, embed vào HUD.tscn
