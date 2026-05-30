# Plan: Weather Sync & Day/Night Cycle

Status: Complete
Date: 2026-05-28
Mode: Hard
Testing: skipped (--no-test)

## Session Notes

Code review APPROVED. All 4 phases implemented and working:
- Phase 1: WeatherState domain class complete
- Phase 2: MockWeatherService + WeatherService complete
- Phase 3: WeatherManager autoload with polling complete
- Phase 4: WeatherOverlay scene with particles/overlay complete

Weather sync system fully functional and integrated into project.

---

## Overview

Synchronise real-world weather conditions and sunrise/sunset time into the game so that GardenScene displays rain, storm particles, and a day/night overlay automatically. The feature spans all four Clean Architecture layers — domain → services → autoloads → scenes — with a MockWeatherService swap path to a real HTTP backend.

---

## Phases

> **Cook order exception:** Phase 4 must be cooked BEFORE Phase 3 because WeatherManager preloads WeatherOverlay.tscn at script load time. Cook order: 1 → 2 → 4 → 3.

- [x] Phase 1: Domain — WeatherState data class (RefCounted, condition enum, is_day computation)
- [x] Phase 2: Services — MockWeatherService (synchronous mock) + WeatherService (HTTP placeholder)
- [x] Phase 3: Autoloads — WeatherManager singleton, Timer polling, HTTPRequest, overlay attachment, project.godot registration (**cook last**)
- [x] Phase 4: Scenes — WeatherOverlay CanvasLayer with CPUParticles2D rain/wind + DayNightOverlay ColorRect + tween transitions (**cook before Phase 3**)

---

## Architecture Diagram

```
domain/
  WeatherState.gd           ← pure data, RefCounted, condition enum, is_day bool
        ↑ imported by
services/
  MockWeatherService.gd     ← RefCounted, @export condition/sunrise/sunset, synchronous
  WeatherService.gd         ← RefCounted, HTTP JSON parser placeholder
        ↑ instantiated by
autoloads/
  WeatherManager.gd         ← Node, owns Timer + HTTPRequest + WeatherOverlay as children
                               @export var mock_condition — changeable in Inspector during play
        ↓ emits signal
scenes/
  shared/WeatherOverlay.gd  ← CanvasLayer layer=1, CPUParticles2D + ColorRect, connects weather_changed
```

---

## Signal Chain

```
[Timer.timeout — every 600 s]
  → WeatherManager._on_timer_timeout()
      → if use_mock: state = _mock_service.get_state()
        else: _http.request(endpoint)

[HTTPRequest.request_completed]
  → WeatherManager._on_request_completed(result, code, headers, body)
      → if result != OK or code != 200: push_warning; keep _current_state
        else: state = _weather_service.parse_response(json)
      → if state differs from _current_state:
          _current_state = state
          weather_changed.emit(state)
            → WeatherOverlay._on_weather_changed(state)
                → apply_state(state)   ← tweens particles + overlay color

[WeatherOverlay._ready()]
  → WeatherManager.weather_changed.connect(_on_weather_changed)
  → WeatherManager.get_current_state()  ← apply initial state immediately
```

---

## Story Coverage

| Story | Priority | Phase |
|---|---|---|
| Rain particles when RAINY | P1 | Phase 4 |
| Storm: rain + wind particles simultaneously | P1 | Phase 4 |
| Night darkening from sunrise/sunset Unix time | P1 | Phase 1 + Phase 4 |
| Smooth fade transition between conditions (≥ 0.5 s) | P2 | Phase 4 |
| CLOUDY gray tint at opacity 0.15 | P2 | Phase 4 |
| Mock @export for editor testing without BE | P1 | Phase 2 |
| HTTP resilience — keep state on timeout/fail | P1 | Phase 3 |

---

## Dependencies

- `autoloads/FocusManager.gd` — already exists; WeatherManager loads AFTER it in project.godot
- `scenes/shared/` folder — already exists (Portal.tscn, Player.tscn); WeatherOverlay.tscn added here
- No GardenScene script changes required — WeatherOverlay is a child of the WeatherManager autoload node and persists across all scene changes automatically
- BE JSON format (`condition`, `sunrise`, `sunset` field names) — unconfirmed; WeatherService.parse_response() must be updated when BE is ready
- No new external plugins or Android permissions needed (HTTPRequest is built-in)

---

## Risks

- HIGH: CPUParticles2D STORM (300 rain + 100 wind = 400 total active particles) may drop FPS below threshold on low-end Android devices. Mitigation: enforce hard caps in the scene (amount property capped in .tscn), add `@export var particle_quality_multiplier: float = 1.0` on WeatherOverlay for future LOD scaling.
- HIGH: WeatherOverlay added as child of WeatherManager autoload means it renders above ALL scenes including UI. Mitigation: set `layer = 10` (below FocusTimerUI at layer 10 — if conflict arises, lower WeatherOverlay to layer 5 matching original FR-04 spec value).
- MEDIUM: HTTPRequest timeout (default 0 = no timeout). If BE hangs, the request never completes and `_on_request_completed` never fires. Mitigation: set `_http.timeout = 5.0` in WeatherManager._ready() and handle `result != HTTPRequest.RESULT_SUCCESS` as a keep-state no-op.
- MEDIUM: `Time.get_unix_time_from_system()` returns device local time as Unix UTC. If the device clock is wrong, is_day will be miscalculated. Mitigation: document assumption; no client-side fix for wrong device clock.
- LOW: WeatherManager loads last — any autoload that calls `WeatherManager.get_current_state()` in its own _ready() will get null. Mitigation: WeatherManager.get_current_state() returns a safe default WeatherState (SUNNY, is_day=true) if _current_state is null.
- LOW: Tween node leaked if `apply_state()` is called again before the previous tween finishes. Mitigation: call `tween.kill()` at the start of `apply_state()` before creating a new one.
