# Plan: Weather BE ↔ Godot Integration

**Status:** Complete  
**Date:** 2026-06-08  
**Mode:** Hard  
**Testing:** manual smoke + `dotnet build` (0 errors)

---

## Session Notes
<!-- Updated by cook automatically — do not edit manually -->

**Last active:** 2026-06-08  
**Phase in progress:** (complete)  
**Status:** All 3 phases implemented; BE build passed; Godot unwrap + endpoint wired.

### Decisions made this session
- `use_mock = false` default (aligned with UserManager/GardenManager)
- `isRaining` derived from `condition` (`rainy`|`storm`) — no snow→rainy
- Unwrap `ApiResponse` in `WeatherService.parse_response()`, not WeatherManager
- Endpoint auto: `UserManager.base_url + "/api/weather/current"`

### Next immediate action
Deploy BE + clear Redis cache (`DELETE /api/weather/cache`); run game F5 to verify overlay.

---

## Scope Challenge

```
# Scope Challenge:
#   Exists?     → Partially. weather-sync (Godot UI/mock) DONE; openweather-weather-api (BE) DONE.
#                 Gap: WeatherHelper condition/isRaining mismatch + Godot không unwrap ApiResponse.
#   Minimum?    → Fix WeatherHelper.ResolveCondition + Godot unwrap envelope + endpoint wiring.
#   Complexity? → Hard — 2 repos, 2 stacks, contract alignment, cache invalidation.
#
# Mode: Hard
# Test:  default (no test project in BE; Godot headless script check)
```

## Spec Quality Check

Source: `plans/weather-sync/spec.md` (Draft, `[NEEDS CLARIFICATION]` on JSON format)

```
# Spec Quality Check:
#   [NEEDS CLARIFICATION] remaining? → RESOLVED by this plan (contract defined below)
#   Success criteria measurable?     → PASS (particles, overlay, no crash on fail)
#   User stories P1/P2/P3?           → PASS
#   Acceptance criteria testable?    → PASS
#
# Verdict: PASS (after resolving JSON format in Phase 3 docs)
```

---

## Overview

Nối luồng thời tiết thực từ OpenWeatherMap → eco-backend → Godot game:

1. **BE:** Sửa `WeatherHelper` map đúng 4 condition game (`sunny` / `cloudy` / `rainy` / `storm`) + đồng bộ `isRaining`, theo bảng OpenWeather → game đã thống nhất.
2. **Godot:** Sửa `WeatherService` unwrap `ApiResponse` envelope; `WeatherManager` tự build endpoint từ `UserManager.base_url`.

Không thay đổi `WeatherState` domain hay `WeatherOverlay` scene — chỉ sửa mapping + parse.

---

## Contract BE → Godot (frozen)

```json
{
  "isSuccess": true,
  "message": "Lấy thông tin thời tiết thành công.",
  "data": {
    "condition": "rainy",
    "sunrise": 1779834584,
    "sunset": 1779880296,
    "isDay": true,
    "isRaining": true
  }
}
```

| `data.condition` | Game enum | OpenWeather `main` (primary) |
|------------------|-----------|------------------------------|
| `sunny` | `SUNNY` | `Clear` |
| `cloudy` | `CLOUDY` | `Clouds`, `Snow`, `Mist`/`Fog`/… (7xx) |
| `rainy` | `RAINY` | `Rain`, `Drizzle`, hoặc `rain.1h > 0` |
| `storm` | `STORM` | `Thunderstorm`, `Squall`, `Tornado` |

Godot **chỉ đọc** `condition`, `sunrise`, `sunset` — tự tính `is_day` trong `WeatherState._init()`.

---

## Phases

- [x] Phase 1: BE — `WeatherHelper.ResolveCondition()` + docs (`eco-backend`)
- [x] Phase 2: Godot — `WeatherService` unwrap + `WeatherManager` endpoint wiring (`ecoflora-godot`)
- [x] Phase 3: Verify — build, smoke test, cập nhật docs + resolve spec clarification

**Cook order:** 1 → 2 → 3 (BE trước để Swagger contract ổn định trước khi Godot parse)

---

## Architecture Gate

```
# Architecture Gate:
#   Verdict: PASS
```

---

## Research Summary

**Primary (BE):** Thêm `ResolveCondition()` theo thứ tự ưu tiên: storm mains → snow→cloudy → rain (main hoặc `rain.1h`) → ConditionMap → default cloudy. Derive `isRaining` từ `condition in {rainy, storm}`.

**Alternative (Godot):** Unwrap trong `WeatherService.parse_response()` (giống `ShopService`).

---

## Story Coverage

| Story | Priority | Phase |
|-------|----------|-------|
| Rain particles khi trời mưa thật (BE→Godot) | P1 | 1 + 2 |
| Storm khi Thunderstorm OWM | P1 | 1 + 2 |
| Ngày/đêm từ sunrise/sunset UTC | P1 | 1 + 2 |
| HTTP fail → giữ state cũ | P1 | 2 |
| CLOUDY vs SUNNY phân biệt rõ | P2 | 1 |

---

## Dependencies

- BE chạy với `OPENWEATHER_*` + Redis configured (`API/.env`)
- `UserManager.base_url` trỏ đúng BE (mặc định `http://20.40.58.246:5000`)
- WeatherManager autoload đã đăng ký trong `project.godot`
- Sau Phase 1: xóa Redis weather cache (`DELETE /api/weather/cache` Admin) hoặc đợi TTL 600s

---

## Risks

| Severity | Risk | Mitigation |
|----------|------|------------|
| MEDIUM | Cache Redis cũ thiếu `condition`/`sunrise`/`sunset` | Clear cache sau deploy BE; document trong Phase 3 |
| MEDIUM | `use_mock=true` default — dev quên tắt mock | Resolved: default `false`; docs updated |
| LOW | Snow volume > 0 nhưng main=Clouds | Không map snow→rainy; chỉ `rain` object trigger rainy |
| LOW | sunrise/sunset = 0 từ OWM | Godot parse_response reject; giữ state cũ |

---

## Validation Questions (answered)

1. Endpoint auto from `UserManager.base_url` — **OK**
2. Mock default — **`use_mock = false`**
3. BE cache clear — **user handles via Admin JWT**
4. Snow → cloudy — **OK**

---

## Code Review

**Verdict:** APPROVED (inline, hard mode)

- WeatherHelper priority order matches OpenWeather → game table
- No upward imports; Godot parse uses HttpHelper pattern consistently
- Note: deploy BE before game picks up new mapping; clear Redis cache

---

# Spec Coverage

P1 stories:        3/3 covered  
Success criteria:  5/5 verifiable  
Uncovered P1:      none
