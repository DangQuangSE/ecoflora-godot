# Phase 1: Domain — WeatherState

testing: skipped (--no-test)

## Layer

`domain/` — RefCounted only, no Node, no autoload imports, no signals. This class has zero dependencies on the rest of the game and can be instantiated without a running scene tree.

## Files

| File | Layer | Action |
|---|---|---|
| `domain/WeatherState.gd` | domain | CREATE |

---

## Requirements

Deliver a pure-data `WeatherState` class that holds a single snapshot of weather conditions. It computes `is_day` from sunrise/sunset Unix timestamps at construction time and never needs to be updated — callers create a new instance per poll cycle.

---

## Story Coverage

| Story | Priority | Satisfied by |
|---|---|---|
| Rain particles when RAINY | P1 | `condition` field holds `Condition.RAINY` |
| Storm rain + wind simultaneously | P1 | `condition` field holds `Condition.STORM` |
| Night darkening from real sunrise/sunset | P1 | `is_day` computed from `sunrise_unix`/`sunset_unix` vs current Unix time |
| CLOUDY gray tint | P2 | `condition` field holds `Condition.CLOUDY` |

---

## Steps

1. Create `domain/WeatherState.gd` as a `RefCounted` with `class_name WeatherState`. Define the condition enum at the top of the file:
   ```gdscript
   class_name WeatherState
   extends RefCounted

   enum Condition { SUNNY, CLOUDY, RAINY, STORM }
   ```

2. Add typed instance variables below the enum. All four must have explicit type hints — no untyped vars:
   ```gdscript
   var condition: Condition
   var is_day: bool
   var sunrise_unix: int
   var sunset_unix: int
   ```

3. Add the constructor `_init` that accepts the condition and the two Unix timestamps, then computes `is_day` inline using `Time.get_unix_time_from_system()`. The comparison logic is the single source of truth for day/night throughout the whole feature — do not duplicate it elsewhere:
   ```gdscript
   func _init(cond: Condition, sunrise: int, sunset: int) -> void:
       condition = cond
       sunrise_unix = sunrise
       sunset_unix = sunset
       var now := int(Time.get_unix_time_from_system())
       is_day = now >= sunrise_unix and now < sunset_unix
   ```
   `now >= sunrise_unix and now < sunset_unix` — strictly less than sunset so the exact sunset second is treated as nightfall.

4. Add a convenience factory `make_default() -> WeatherState` as a static function that returns a SUNNY daytime state when no real data is available yet. This is used by WeatherManager to initialise `_current_state` before the first poll completes:
   ```gdscript
   static func make_default() -> WeatherState:
       # Wide ±12 h window guarantees is_day = true for the entire session
       var base := int(Time.get_unix_time_from_system())
       var fake_sunrise := base - 43200  # 12 hours ago
       var fake_sunset  := base + 43200  # 12 hours from now
       return WeatherState.new(Condition.SUNNY, fake_sunrise, fake_sunset)
   ```

5. Add `equals(other: WeatherState) -> bool` so WeatherManager can detect whether the new poll result actually differs from the cached state before emitting `weather_changed`. Only emit the signal when something has changed:
   ```gdscript
   func equals(other: WeatherState) -> bool:
       if other == null:
           return false
       return condition == other.condition and is_day == other.is_day
   ```
   Note: `sunrise_unix` and `sunset_unix` are intentionally excluded from the equality check — they are raw data fields, not display-relevant state. Only `condition` and `is_day` drive visual output.

---

## Success Criteria

- `WeatherState.new(WeatherState.Condition.RAINY, 0, 99999999999)` produces an object where `condition == Condition.RAINY` and `is_day == true` (current time is well within the sunrise/sunset window).
- `WeatherState.new(WeatherState.Condition.SUNNY, 0, 1)` produces `is_day == false` (sunset was at Unix second 1, which is in the past).
- `equals()` returns `false` when comparing a RAINY+is_day=true state against a SUNNY+is_day=true state.
- `equals()` returns `true` when both condition and is_day match, regardless of differing sunrise/sunset values.
- `make_default()` returns a non-null WeatherState with `condition == Condition.SUNNY` and `is_day == true`.
- Static analysis passes: `godot --headless --check-only --script res://domain/WeatherState.gd` exits with no errors.

---

## Risks

- `Time.get_unix_time_from_system()` returns a float in Godot 4 — the `int()` cast in `_init` truncates sub-second precision, which is acceptable for sunrise/sunset comparison (accuracy needed is minutes, not milliseconds).
- `make_default()` uses relative offsets from current time so it remains correct regardless of when the game launches. A hardcoded timestamp would become stale.
