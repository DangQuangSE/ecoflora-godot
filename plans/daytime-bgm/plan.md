# Daytime BGM — sunny_sound.mp3

## Overview

Phát nhạc nền `res://sounds/sunny_sound.mp3` khi game ở trạng thái ban ngày (`WeatherState.is_day == true`), đối xứng với `night-sound.mp3` đã có cho ban đêm. Thay đổi chỉ trong `AudioManager` — không cần sửa WeatherManager hay scene.

## Scope Challenge

| | |
|---|---|
| **Exists?** | Một phần — ban đêm đã có BGM; ban ngày chỉ dừng night track, chưa phát sunny |
| **Minimum** | Thêm volume entry + đổi nhánh `is_day` trong `update_bgm_for_weather_state()` |
| **Mode** | Fast — 1 file, pattern quen thuộc |

## User Stories

| Priority | Story |
|----------|-------|
| P1 | Khi vào Garden/School/Classroom lúc ban ngày + SUNNY/CLOUDY, nghe `sunny_sound.mp3` loop |
| P1 | Ban ngày RAINY/STORM — không phát sunny (dừng weather BGM nếu đang phát) |
| P1 | Khi chuyển ban ngày ↔ ban đêm, BGM crossfade mượt (0.5s) |
| P2 | Auth scenes (Login/Register) vẫn dùng `lobby_v2.mp3`, không bị sunny ghi đè |

## Phases

- [ ] [Phase 1: AudioManager day BGM](phase-01-audiomanager-day-bgm.md)

## Architecture Gate

```
Layer mapping:
  domain/     → không đụng
  services/   → không đụng
  autoloads/  → AudioManager.gd
  scenes/     → không đụng

Dependency arrows: PASS — chỉ autoloads
Violations: none

Anti-pattern flags: all NO
Verdict: PASS
```

## Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Volume sunny quá to/nhỏ so night | LOW | Bắt đầu -10 dB (cùng night), chỉnh sau khi nghe thử |
| `play_bgm` early-return khi cùng path đang play | LOW | Logic hiện tại đã xử lý — không cần đổi |
| Chuyển scene auth → game | LOW | `SceneTransition` đã gọi `update_bgm_for_weather_state()` sau load |

## Test Plan (manual smoke)

1. Mock `WeatherManager.mock_is_day = true` → vào Garden → nghe sunny loop
2. Toggle `mock_is_day = false` → crossfade sang night-sound
3. Toggle lại `true` → crossfade về sunny
4. Login scene → lobby_v2 vẫn phát, không sunny
5. Fade Login → Garden (ban ngày) → lobby dừng, sunny bắt đầu

## Cook Command

```
/ck:cook --fast plans/daytime-bgm/plan.md
```
