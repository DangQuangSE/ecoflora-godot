# Footstep v2 — Continuous Walking Loop

## Overview

Thay tiếng chân procedural / interval-based hiện tại bằng `res://sounds/foot_step_v2.mp3` phát **liên tục** khi player di chuyển: dừng khi đứng yên, phát lại từ đầu khi bắt đầu đi, loop khi clip hết mà vẫn đang di chuyển.

## Scope Challenge

```
# Scope Challenge:
#   Exists?     → Có — Player.gd timer 0.35s + AudioManager procedural WAV
#   Minimum?    → Load MP3 + đổi Player play/stop theo velocity
#   Complexity? → Fast — 2 file, pattern quen (AudioStreamPlayer2D)
#
# Mode: Fast
# Test:  default (manual smoke)
```

## User Stories

| Priority | Story |
|----------|-------|
| P1 | Di chuyển → nghe `foot_step_v2.mp3` liên tục |
| P1 | Dừng di chuyển → tiếng chân dừng ngay |
| P1 | Đi lại sau khi dừng → phát từ đầu clip |
| P1 | Đang đi mà clip hết → loop tiếp |
| P2 | Garden / School / Classroom đều dùng chung `Player.gd` — không cần sửa từng scene |

## Phases

- [ ] [Phase 1: AudioManager footstep asset](phase-01-audiomanager-footstep.md)
- [ ] [Phase 2: Player continuous footstep](phase-02-player-footstep.md)

## Architecture Gate

```
Layer mapping:
  domain/     → không đụng
  services/   → không đụng
  autoloads/  → AudioManager.gd
  scenes/     → Player.gd

Dependency arrows: scenes → autoloads → domain — PASS
Violations: none

Anti-pattern flags: all NO
Verdict: PASS
```

## Hiện trạng

- `Player._handle_footsteps()` dùng `FOOTSTEP_INTERVAL = 0.35s`, gọi `play()` từng nhịp + random pitch → nghe cứng
- `AudioManager` sinh procedural WAV hoặc load `footstep.wav` cũ
- Chỉ `Player.gd` gọi `get_footstep_stream()`

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| MP3 chưa import | LOW | Godot tự import khi mở project; commit `.import` nếu có |
| Hard stop/start nghe giật | MEDIUM | Có thể thêm fade ngắn sau nếu user phản hồi |
| Volume MP3 quá to | LOW | Đăng ký trong `SFX_VOLUMES` hoặc `@export` trên Player |

## Test Plan (manual)

1. Garden — giữ joystick → nghe loop liên tục
2. Thả joystick → im lặng ngay
3. Giữ lại → phát từ đầu (không nối giữa chừng clip cũ)
4. Đi > độ dài clip → không bị im giữa chừng (loop)
5. School / Classroom — hành vi giống Garden

## Cook Command

```
/ck:cook --fast plans/footstep-v2/plan.md
```
