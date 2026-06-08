# Phase 2: Godot — WeatherService Unwrap + Endpoint Wiring

**Repo:** `ecoflora-godot`  
**Layer:** services → autoloads  
**Depends on:** Phase 1 (BE contract stable)  
**Covers:** P1 real API rain/storm/day-night, FR-06 HTTP parse

---

## Goal

Godot parse đúng `ApiResponse<WeatherDto>` từ BE, map sang `WeatherState`, poll endpoint tự động từ `UserManager.base_url`.

---

## Files

| File | Layer | Action |
|------|-------|--------|
| `services/WeatherService.gd` | services | EDIT |
| `autoloads/WeatherManager.gd` | autoloads | EDIT |

**Không đổi:** `domain/WeatherState.gd`, `scenes/shared/WeatherOverlay.gd`

---

## Implementation Steps

### 1. `WeatherService.gd` — unwrap envelope

Import pattern giống `ShopService` / `VitalityService`:

```gdscript
func parse_response(envelope: Dictionary) -> WeatherState:
    var data: Variant = HttpHelper.unwrap_envelope(envelope)
    if data == null or not data is Dictionary:
        push_warning("WeatherService.parse_response: envelope unwrap failed")
        return null
    var payload: Dictionary = data
    # ... existing field extraction from payload (not envelope)
```

Field lookup — hỗ trợ camelCase từ BE (Godot JSON keys as-is):

```gdscript
var cond_str: String = str(payload.get("condition", "")).to_lower()
var sunrise_val: Variant = payload.get("sunrise", null)
var sunset_val: Variant = payload.get("sunset", null)
```

Giữ nguyên `condition_map` → `WeatherState.Condition` enum mapping.

Validation giữ nguyên:
- Unknown condition → null + push_warning
- sunrise/sunset missing or non-numeric → null
- sunrise >= sunset → null

**Không** đọc `isDay`/`isRaining` từ BE — `WeatherState._init()` tự tính `is_day`.

### 2. `WeatherManager.gd` — endpoint wiring

Trong `_ready()`, sau khi tạo `_weather_service`:

```gdscript
func _resolve_weather_endpoint() -> String:
    if not weather_endpoint.is_empty():
        return weather_endpoint
    return UserManager.base_url + "/api/weather/current"

# in _ready():
_weather_service.endpoint = _resolve_weather_endpoint()
```

Trong `_on_timer_timeout()` non-mock path: dùng `_weather_service.endpoint` (đã resolve).

Optional improvement — re-resolve nếu `UserManager.base_url` thay đổi runtime (low priority, skip unless needed).

### 3. Mock path unchanged

Giữ `use_mock = true` default — dev test offline với Inspector `Mock Condition`.

Production: set `Use Mock = false` trong Remote Inspector hoặc `@export var use_mock: bool = false` nếu user confirms in validation.

---

## Signal / Flow (unchanged)

```
Timer → HTTP GET endpoint
  → _on_request_completed
    → json.parse(body)
    → _weather_service.parse_response(envelope_dict)  # now unwraps internally
    → _apply_new_state(WeatherState)
    → weather_changed.emit()
    → WeatherOverlay.apply_state()
```

---

## Verification

```bash
cd d:\FPT\8thSemester\EXE2\ecoflora-godot
godot --headless --check-only --script res://autoloads/WeatherManager.gd
```

Manual smoke (BE running, OpenWeather configured):

1. Remote Inspector: `WeatherManager.use_mock = false`
2. Confirm `weather_endpoint` empty → auto uses `UserManager.base_url`
3. Play game → Output không có parse warnings
4. Verify overlay matches real weather (or force BE cache clear + re-fetch)

Negative tests:

| Input | Expected |
|-------|----------|
| `{ "isSuccess": false }` | Keep current state, push_warning |
| `{ "isSuccess": true, "data": {} }` | Keep state (missing fields) |
| HTTP timeout / non-200 | Keep state (existing behavior) |

---

## Architecture Compliance

- `WeatherService` imports `HttpHelper` (same services layer) + `WeatherState` (domain) ✓
- `WeatherManager` imports services via instantiation, không import scenes ✓
- No `print()` — `push_warning()` only ✓
