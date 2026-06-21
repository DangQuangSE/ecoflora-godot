# Plan: Watering Sound — Phát watering.wav khi tưới nước

Status: ✅ Complete
Date: 2026-06-19
Mode: Fast

## Overview

Khi người chơi dùng bình tưới (water / action_type 0) lên ô hoa đã trồng, phát âm thanh `res://sounds/watering.wav` ngay tại optimistic predict — cùng pattern với `plant.wav` và `harvest.wav`.

## Scope Challenge

| | |
|---|---|
| **Exists?** | Chưa — `watering.wav` đã có asset; chưa có wiring SFX |
| **Minimum?** | Thêm entry `SFX_VOLUMES` + `AudioManager.play_sfx` tại 2 điểm optimistic water (mock + BE) |
| **Complexity** | Fast — 2 file autoloads, pattern quen từ plant/harvest |

Mode: **Fast**
Test: **default**

## Phases

- [x] Phase 1: Wire watering.wav tại GardenManager + AudioManager

## Architecture Gate

| Check | Result |
|---|---|
| **Layer mapping** | `autoloads/` only — GardenManager, AudioManager |
| **Dependency arrows** | autoloads → autoloads (GardenManager → AudioManager) — hợp lệ |
| **domain/services** | Không đụng |
| **extends Node in domain/?** | NO |
| **get_tree() in domain/?** | NO |
| **print() anywhere?** | NO (new code dùng push_warning/push_error nếu cần) |
| **Manager→View direct call?** | NO — audio từ manager, UI refresh qua signal như cũ |
| **yield?** | NO |
| **Autoload imported from domain/services/?** | NO |
| **Verdict** | **PASS** |

## Dependencies

- `sounds/watering.wav` — asset đã có (Godot tự tạo `.import` khi mở editor)
- `autoloads/AudioManager.gd` — thêm volume entry
- `autoloads/GardenManager.gd` — phát SFX khi water optimistic thành công

## Acceptance Criteria

- [ ] Tưới nước thành công (mock hoặc BE) → nghe `watering.wav`
- [ ] Tưới bị chặn (max stage, không có item, plot pending, plot trống) → **không** phát sound
- [ ] Fertilize / pesticide → **không** phát `watering.wav`
- [ ] Rollback sau lỗi BE → không phát thêm sound (sound chỉ lúc optimistic thành công)
- [ ] Volume cân bằng với plant/harvest (~ -15 dB)

## Risks

| Risk | Mitigation |
|---|---|
| `watering.wav.import` chưa có | Mở Godot editor một lần hoặc chạy import; `play_sfx` log push_error nếu load fail |
| Mock vs BE path khác nhau | Phát ở cả `_mock_care` (action_type==0) và `_care_apply_optimistic` (action_value==0) |
| Double sound nếu gọi 2 lần | Chỉ gọi sau khi guard pass, trước async |

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-19
**Phase in progress:** phase-01-watering-sfx
**Status:** Ready to cook
