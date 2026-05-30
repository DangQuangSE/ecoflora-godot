# Phase 2: Services — MockWeatherService + WeatherService

testing: skipped (--no-test)

## Layer

`services/` — RefCounted classes, imports `domain/` only. Never import autoloads. Never extend Node. Reference pattern: `services/MockGardenService.gd` (already exists).

## Files

| File | Layer | Action |
|---|---|---|
| `services/MockWeatherService.gd` | services | CREATE |
| `services/WeatherService.gd` | services | CREATE |

---

## Requirements

Deliver two service classes that both produce a `WeatherState` from different sources. `MockWeatherService` is synchronous and @export-configurable so any developer can set condition/sunrise/sunset in the Godot Inspector without touching code. `WeatherService` is the real HTTP parser placeholder — it accepts a parsed JSON dictionary and returns a `WeatherState`, ready to be wired in when the backend is available.

---

## Story Coverage

| Story | Priority | Satisfied by |
|---|---|---|
| Mock @export for editor testing | P1 | `MockWeatherService.@export var mock_condition` + `mock_sunrise_hour` + `mock_sunset_hour` |
| HTTP resilience — keep state on failure | P1 | `WeatherService.parse_response()` returns null on malformed JSON; WeatherManager handles null by keeping old state |
| Swap mock → real with one line change | P1 | Both classes expose the same `get_state()` / `parse_response()` surface; WeatherManager switches via `use_mock` flag |

---

## Steps

1. Create `services/MockWeatherService.gd` as a `RefCounted` with `class_name MockWeatherService`. Declare plain (non-@export) vars — `@export` has no effect on RefCounted instantiated in code, so they are set directly in WeatherManager._ready() during development:
   ```gdscript
   class_name MockWeatherService
   extends RefCounted

   var mock_condition: WeatherState.Condition = WeatherState.Condition.SUNNY
   var mock_sunrise_hour: int = 6    # 06:00 LOCAL time
   var mock_sunset_hour: int = 18    # 18:00 LOCAL time
   ```
   `mock_sunrise_hour` and `mock_sunset_hour` are integers 0–23 in the **device's local time zone**. They are converted to UTC Unix timestamps inside `get_state()` using the system timezone offset.

2. Implement `get_state() -> WeatherState` on MockWeatherService. Convert the local hour integers to UTC Unix timestamps correctly using `Time.get_time_zone_from_system()`:
   ```gdscript
   func get_state() -> WeatherState:
       var now := int(Time.get_unix_time_from_system())
       # Convert local hours to UTC by anchoring to today's local midnight
       var tz_offset_sec: int = Time.get_time_zone_from_system().bias * 60
       var today_local_midnight_utc: int = ((now + tz_offset_sec) / 86400) * 86400 - tz_offset_sec
       var sunrise := today_local_midnight_utc + mock_sunrise_hour * 3600
       var sunset  := today_local_midnight_utc + mock_sunset_hour  * 3600
       return WeatherState.new(mock_condition, sunrise, sunset)
   ```
   This correctly anchors to today's LOCAL calendar date for any timezone — a developer in Vietnam (UTC+7) setting `mock_sunrise_hour = 6` gets 06:00 local, not 06:00 UTC.

3. Create `services/WeatherService.gd` as a `RefCounted` with `class_name WeatherService`. Declare `endpoint` as a plain var — `@export` has no effect on RefCounted. The URL is set in `WeatherManager._ready()` when the backend is ready:
   ```gdscript
   class_name WeatherService
   extends RefCounted

   var endpoint: String = ""  # set via WeatherManager._ready(): _weather_service.endpoint = "https://..."
   ```

4. Implement `parse_response(json: Dictionary) -> WeatherState` on WeatherService. Map BE string values to the enum and extract sunrise/sunset. Return `null` on any missing or unrecognised field — WeatherManager treats null as "keep current state":
   ```gdscript
   func parse_response(json: Dictionary) -> WeatherState:
       if not json.has("condition") or not json.has("sunrise") or not json.has("sunset"):
           push_warning("WeatherService.parse_response: missing required fields in response")
           return null
       var condition_map := {
           "sunny":  WeatherState.Condition.SUNNY,
           "cloudy": WeatherState.Condition.CLOUDY,
           "rainy":  WeatherState.Condition.RAINY,
           "storm":  WeatherState.Condition.STORM,
       }
       var cond_str: String = str(json["condition"]).to_lower()
       if not condition_map.has(cond_str):
           push_warning("WeatherService.parse_response: unknown condition '%s'" % cond_str)
           return null
       if not (json["sunrise"] is int or json["sunrise"] is float):
           push_warning("WeatherService.parse_response: 'sunrise' is not a number")
           return null
       if not (json["sunset"] is int or json["sunset"] is float):
           push_warning("WeatherService.parse_response: 'sunset' is not a number")
           return null
       var sunrise: int = int(json["sunrise"])
       var sunset:  int = int(json["sunset"])
       return WeatherState.new(condition_map[cond_str], sunrise, sunset)
   ```
   `to_lower()` makes the mapping case-insensitive — BE can send "Sunny" or "SUNNY" and it will match.

5. Add a stub `get_endpoint() -> String` to WeatherService that returns `endpoint` and emits a warning if the string is empty. WeatherManager calls this before firing the HTTP request:
   ```gdscript
   func get_endpoint() -> String:
       if endpoint.is_empty():
           push_warning("WeatherService: endpoint is not configured — HTTP request will be skipped")
       return endpoint
   ```
   WeatherManager must check `get_endpoint().is_empty()` and skip the HTTP request rather than sending a request to an empty URL, which would produce a Godot engine error.

---

## Success Criteria

- `MockWeatherService.new().get_state()` returns a non-null `WeatherState` with `condition == SUNNY` and `is_day` matching whether the current device time is between 06:00 and 18:00.
- Setting `mock_condition = WeatherState.Condition.STORM` and calling `get_state()` returns a state where `condition == STORM`.
- Setting `mock_sunrise_hour = 0` and `mock_sunset_hour = 23` and calling `get_state()` at any reasonable hour returns `is_day == true`.
- `WeatherService.new().parse_response({})` returns `null` and emits a push_warning (visible in Godot Output panel).
- `WeatherService.new().parse_response({"condition": "rainy", "sunrise": 1700000000, "sunset": 1700050000})` returns a WeatherState with `condition == RAINY`.
- `WeatherService.new().parse_response({"condition": "FOG", "sunrise": 0, "sunset": 0})` returns `null` (unknown condition).
- Static analysis passes on both files with `--check-only`.

---

## Risks

- BE may send `"condition": "rain"` instead of `"rainy"` — the `condition_map` dictionary in `parse_response` must be updated to match exact BE field values once the backend contract is confirmed. The `[NEEDS CLARIFICATION]` item in the spec is still open.
- `int(json["sunrise"])` will silently cast a float or string to int — this is acceptable since Unix timestamps fit in a 64-bit int with no precision loss, but a string like `"not_a_number"` will become 0. Add a type check if the BE proves unreliable.
- MockWeatherService `@export` fields only work when the class is attached to a Node in the scene tree. Since MockWeatherService is a RefCounted instantiated in WeatherManager code, the exports are for documentation/IDE hints only — actual overrides must be set via code in WeatherManager._ready() during development.
