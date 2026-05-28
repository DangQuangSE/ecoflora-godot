# Phase 4: Scenes — WeatherOverlay (CanvasLayer)

testing: skipped (--no-test)

## Layer

`scenes/` — Node/Control trees, reads from autoloads (WeatherManager) and domain (WeatherState) only. Never imported by autoloads or services. WeatherOverlay is owned by WeatherManager and does not need to be added to any game scene manually.

## Files

| File | Layer | Action |
|---|---|---|
| `scenes/shared/WeatherOverlay.tscn` | scenes | CREATE — CanvasLayer root with CPUParticles2D + ColorRect children |
| `scenes/shared/WeatherOverlay.gd` | scenes | CREATE — apply_state, tween transitions, signal connection |

---

## Requirements

Deliver a `WeatherOverlay` CanvasLayer that listens to `WeatherManager.weather_changed`, translates each `WeatherState` into the correct particle configuration and overlay color, and transitions between states with a tween of at least 0.5 seconds so changes feel smooth rather than jarring.

---

## Story Coverage

| Story | Priority | Satisfied by |
|---|---|---|
| Rain particles when RAINY | P1 | `_rain.emitting = true`, amount=150, direction downward |
| Storm rain + wind particles | P1 | `_rain.emitting = true` (amount=300) + `_wind.emitting = true` (amount=100) |
| Night darkening | P1 | `_day_night` ColorRect alpha set to 0.5 when `is_day == false` |
| Smooth fade transition ≥ 0.5 s | P2 | Tween on `_day_night:modulate:a` and particle `amount` interpolation |
| CLOUDY gray tint at opacity 0.15 | P2 | `_day_night` ColorRect color set to gray with alpha=0.15 |

---

## Steps

1. Build `scenes/shared/WeatherOverlay.tscn` in the Godot Editor. Set the scene root to a `CanvasLayer` node named `WeatherOverlay` with `layer = 1` (purely atmospheric — below all UI panels, above scene world tiles). Attach `WeatherOverlay.gd` as the script. Add three child nodes in this exact order:
   - `RainParticles` — CPUParticles2D, `emitting = false`, `amount = 150`
   - `WindParticles` — CPUParticles2D, `emitting = false`, `amount = 100`
   - `DayNightOverlay` — ColorRect, position `(0, 0)`, size `(720, 1600)` (tall enough to cover any portrait layout), `color = Color(0, 0, 0, 0)` (fully transparent by default)

   Save the scene. The 720×1600 ColorRect is intentionally oversized to handle devices taller than the base 920px viewport — it costs nothing at runtime since it is a simple rect.

2. Configure `RainParticles` (CPUParticles2D) properties in the Inspector. These values represent the RAINY preset — STORM overrides amount and direction at runtime via `_set_particles()`:
   - `direction = Vector3(0.0, 1.0, 0.0)` (**Vector3**, not Vector2 — CPUParticles2D.direction is Vector3 in Godot 4)
   - `spread = 5.0` (degrees — nearly vertical fall)
   - `lifetime = 2.5`
   - `gravity = Vector3(0, 98, 0)` (use default gravity)
   - `initial_velocity_min = 200.0`, `initial_velocity_max = 300.0`
   - `scale_amount_min = 2.0`, `scale_amount_max = 4.0` (pixel-sized droplets)
   - `color = Color(0.6, 0.7, 1.0, 0.7)` (pale blue, semi-transparent)

   Configure `WindParticles` (CPUParticles2D) for the STORM wind streaks:
   - `direction = Vector3(1.0, 0.3, 0.0)` (**Vector3** — same rule)
   - `spread = 15.0`
   - `lifetime = 1.2`
   - `initial_velocity_min = 300.0`, `initial_velocity_max = 500.0`
   - `scale_amount_min = 1.0`, `scale_amount_max = 2.0`
   - `color = Color(0.8, 0.8, 0.9, 0.4)` (light grey, more transparent than rain)

3. Create `scenes/shared/WeatherOverlay.gd` with `class_name WeatherOverlay` extending `CanvasLayer`. Declare onready references and a tween variable:
   ```gdscript
   class_name WeatherOverlay
   extends CanvasLayer

   @onready var _rain: CPUParticles2D = $RainParticles
   @onready var _wind: CPUParticles2D = $WindParticles
   @onready var _day_night: ColorRect = $DayNightOverlay

   var _tween: Tween = null
   ```

4. Implement `_ready() -> void`. Connect to WeatherManager and immediately apply the current state so the overlay is correct on scene load rather than waiting for the next poll:
   ```gdscript
   func _ready() -> void:
       WeatherManager.weather_changed.connect(_on_weather_changed)
       apply_state(WeatherManager.get_current_state())
   ```
   Connecting in `_ready()` rather than in WeatherManager ensures the overlay is self-contained — it registers itself with the signal rather than being pushed data from outside.

5. Implement `_on_weather_changed(state: WeatherState) -> void` as a thin relay to `apply_state`:
   ```gdscript
   func _on_weather_changed(state: WeatherState) -> void:
       apply_state(state)
   ```
   Keeping it as a separate method (not connecting directly to `apply_state`) makes it easy to add pre-processing (logging, analytics) later without changing the signal wiring.

6. Implement `apply_state(state: WeatherState) -> void`. This is the core method. Kill any running tween first to prevent overlap, then branch on condition:
   ```gdscript
   func apply_state(state: WeatherState) -> void:
       if _tween != null and _tween.is_valid():
           _tween.kill()
       _tween = create_tween().set_parallel(true)

       match state.condition:
           WeatherState.Condition.SUNNY:
               _set_particles(false, false, 150, 100)
               _tween_overlay(Color(0, 0, 0, 0.0 if state.is_day else 0.5))

           WeatherState.Condition.CLOUDY:
               _set_particles(false, false, 150, 100)
               # Day: gray tint 0.15 alpha. Night: dark overlay 0.5 alpha added on top.
               var base_alpha := 0.15 if state.is_day else 0.5
               _tween_overlay(Color(0.15, 0.15, 0.15, base_alpha))

           WeatherState.Condition.RAINY:
               _set_particles(true, false, 150, 100,
                   Vector3(0.0, 1.0, 0.0), 5.0)
               var night_extra := 0.0 if state.is_day else 0.3
               _tween_overlay(Color(0.0, 0.05, 0.1, 0.1 + night_extra))

           WeatherState.Condition.STORM:
               _set_particles(true, true, 300, 100,
                   Vector3(sin(deg_to_rad(25.0)), cos(deg_to_rad(25.0)), 0.0), 15.0)
               var night_extra := 0.0 if state.is_day else 0.3
               _tween_overlay(Color(0.0, 0.0, 0.05, 0.2 + night_extra))
   ```
   The `sin`/`cos` direction vector for STORM tilts rain 25 degrees to the right, matching research findings. `_rain.amount` must be set before `_set_particles()` starts the emitter — Godot reads `amount` when `emitting` is toggled on.

7. Implement the two private helpers `_set_particles` and `_tween_overlay`. These keep `apply_state` readable and centralise the tween duration constant:
   ```gdscript
   const TRANSITION_SEC := 0.6

   func _set_particles(rain_on: bool, wind_on: bool, rain_amt: int, wind_amt: int,
           rain_dir: Vector3 = Vector3(0, 1, 0), rain_spread: float = 5.0) -> void:
       _rain.direction = rain_dir
       _rain.spread = rain_spread
       # Clamp to spec hard caps: rain <= 300, wind <= 150
       _rain.amount = mini(rain_amt, 300)
       _wind.amount = mini(wind_amt, 150)
       _rain.emitting = rain_on
       _wind.emitting = wind_on

   func _tween_overlay(target_color: Color) -> void:
       # _tween already created and set_parallel in apply_state
       _tween.tween_property(_day_night, "color", target_color, TRANSITION_SEC) \
             .set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
   ```
   `TRANSITION_SEC = 0.6` satisfies the P2 story requirement of ≥ 0.5 seconds. `mini()` enforces FR-08 hard caps from the spec (rain ≤ 300, wind ≤ 150).

---

## Success Criteria

- With `MockWeatherService.mock_condition = RAINY`, RainParticles is emitting and WindParticles is not emitting — verified in the Remote scene tree inspector.
- With `mock_condition = STORM`, both RainParticles (amount=300) and WindParticles (amount=100) are emitting simultaneously.
- Setting `mock_sunset_hour` to 1 hour before the current time (forcing `is_day = false`) causes DayNightOverlay color alpha to animate from 0.0 to 0.5 over approximately 0.6 seconds — verified by watching the ColorRect in the editor while in play mode.
- With `mock_condition = CLOUDY` and `is_day = true`, DayNightOverlay color is approximately `Color(0.15, 0.15, 0.15, 0.15)` — verified by reading the color property in the Remote inspector.
- Rapidly toggling `mock_condition` between SUNNY and STORM three times in quick succession does not produce multiple simultaneous tweens — each new `apply_state` call kills the previous tween before starting a new one.
- WeatherOverlay (layer=1) renders above scene world tiles but below all UI panels (FlowerInfoCard layer=8, HUD layer=10, FocusTimerUI layer=10). No z-order conflict possible.
- Static analysis passes: `godot --headless --check-only --script res://scenes/shared/WeatherOverlay.gd` exits with no errors.

---

## Risks

- CPUParticles2D `direction` is a `Vector3` in Godot 4, not `Vector2`. The direction set in the Inspector is `Vector3(x, y, 0)`. In GDScript, setting `_rain.direction` to a Vector2 will cause a type error. Use `Vector3(0, 1, 0)` for downward rain and `Vector3(sin(deg_to_rad(25)), cos(deg_to_rad(25)), 0)` for STORM angle. Adjust Step 6 code accordingly during implementation.
- DayNightOverlay ColorRect `color` property — tweening `color` directly on a ColorRect works via `tween_property`. If the tween targets the wrong property path, no error is thrown but the color will not change. Verify the property path is `"color"` (not `"modulate"`) for ColorRect color changes.
- `_tween.set_parallel(true)` means all `tween_property` calls added after it run simultaneously. This is intentional — future additions (e.g., tweening particle `amount`) will automatically run in parallel with the overlay fade.
- Particle `amount` cannot be smoothly tweened via `tween_property` — it is an integer and changes in discrete steps. This is acceptable for MVP. For smooth particle density ramping in the future, tween a `_rain_intensity: float` variable and apply it in `_process`.
