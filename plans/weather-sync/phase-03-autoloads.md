# Phase 3: Autoloads — WeatherManager + project.godot

testing: skipped (--no-test)

## Layer

`autoloads/` — Node singleton, imports `domain/` and `services/` only. Never imports `scenes/`. The WeatherOverlay scene is loaded as a preload resource and instantiated as a child node — this is not an architectural violation because the overlay is owned and managed entirely by WeatherManager. Reference pattern: `autoloads/FocusManager.gd` (already exists).

## Files

| File | Layer | Action |
|---|---|---|
| `autoloads/WeatherManager.gd` | autoloads | CREATE |
| `project.godot` | config | EDIT — register WeatherManager after FocusManager |

---

## Requirements

Deliver a `WeatherManager` singleton that polls for weather every 600 seconds (using a Timer child node), caches the current `WeatherState`, emits `weather_changed` only when the state actually changes, and owns the `WeatherOverlay` CanvasLayer as a persistent child so it renders across all scene transitions without any per-scene wiring.

---

## Story Coverage

| Story | Priority | Satisfied by |
|---|---|---|
| Weather polled every 10 minutes | P1 | `Timer` child with `wait_time = 600.0`, `autostart = true` |
| HTTP resilience — keep state on timeout/fail | P1 | `_on_request_completed` null-guards; keeps `_current_state` unchanged |
| Swap mock → real with one line change | P1 | `@export var use_mock: bool = true` controls which path runs in `_on_timer_timeout` |
| WeatherOverlay persists across scene changes | P1 | WeatherOverlay instanced as child of WeatherManager autoload node |
| Signal only emitted when state changes | P1 | `_current_state.equals(new_state)` guard before emit |

---

## Steps

1. Create `autoloads/WeatherManager.gd` extending `Node`. Declare the signal and constants at the top, then add the export and private variable declarations:
   ```gdscript
   extends Node

   signal weather_changed(state: WeatherState)

   const POLL_INTERVAL_SEC := 600.0
   const OVERLAY_SCENE := preload("res://scenes/shared/WeatherOverlay.tscn")

   @export var use_mock: bool = true
   @export var mock_condition: WeatherState.Condition = WeatherState.Condition.SUNNY

   var _current_state: WeatherState = null
   var _request_in_flight: bool = false
   var _timer: Timer
   var _http: HTTPRequest
   var _mock_service: MockWeatherService
   var _weather_service: WeatherService
   var _overlay: WeatherOverlay
   ```
   `OVERLAY_SCENE` as a `const` preload ensures the scene resource is loaded once at startup, not on every poll.

2. Implement `_ready() -> void`. Build all child nodes programmatically — no .tscn for WeatherManager itself (autoloads are plain scripts). Order matters: overlay must be added last so it renders above other autoload children:
   ```gdscript
   func _ready() -> void:
       _mock_service = MockWeatherService.new()
       _weather_service = WeatherService.new()

       _timer = Timer.new()
       _timer.wait_time = POLL_INTERVAL_SEC
       _timer.autostart = false  # started manually below, after first poll
       _timer.timeout.connect(_on_timer_timeout)
       add_child(_timer)

       _http = HTTPRequest.new()
       _http.timeout = 5.0
       _http.request_completed.connect(_on_request_completed)
       add_child(_http)

       _overlay = OVERLAY_SCENE.instantiate()
       add_child(_overlay)

       # Initialise with default state so overlay has something to render before first poll
       _current_state = WeatherState.make_default()
       # First poll immediately; start timer AFTER so interval is measured from first poll
       _on_timer_timeout()
       _timer.start()
   ```
   Calling `_on_timer_timeout()` directly in `_ready()` gives the player an immediate weather state instead of a 10-minute blank wait on first launch.

3. Implement `get_current_state() -> WeatherState` as the public read API. Return a safe default if `_current_state` is somehow null (defensive guard for callers during the brief window before `_ready()` finishes):
   ```gdscript
   func get_current_state() -> WeatherState:
       if _current_state == null:
           return WeatherState.make_default()
       return _current_state
   ```

4. Implement `_on_timer_timeout() -> void`. Branch on `use_mock`. For the mock path, call synchronously and apply immediately. For the real path, skip the HTTP request if the endpoint is not configured:
   ```gdscript
   func _on_timer_timeout() -> void:
       if use_mock:
           _mock_service.mock_condition = mock_condition  # sync @export to service
           _apply_new_state(_mock_service.get_state())
       else:
           if _request_in_flight:
               return  # previous request still pending — skip this tick
           var endpoint := _weather_service.get_endpoint()
           if endpoint.is_empty():
               return
           var error := _http.request(endpoint)
           if error != OK:
               push_warning("WeatherManager: HTTPRequest.request() failed with error %d" % error)
               return
           _request_in_flight = true
   ```

5. Implement `_on_request_completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void`. Validate both the transport result and HTTP status code before parsing. Keep the current state on any failure path:
   ```gdscript
   func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
       _request_in_flight = false  # clear guard on every exit path
       if result != HTTPRequest.RESULT_SUCCESS:
           push_warning("WeatherManager: HTTP request failed, result=%d — keeping current state" % result)
           return
       if code != 200:
           push_warning("WeatherManager: HTTP status %d — keeping current state" % code)
           return
       var json := JSON.new()
       var parse_error := json.parse(body.get_string_from_utf8())
       if parse_error != OK:
           push_warning("WeatherManager: JSON parse error — keeping current state")
           return
       var data := json.get_data()
       if not data is Dictionary:
           push_warning("WeatherManager: JSON root is not a Dictionary — keeping current state")
           return
       var new_state := _weather_service.parse_response(data)
       if new_state == null:
           push_warning("WeatherManager: parse_response returned null — keeping current state")
           return
       _apply_new_state(new_state)
   ```

6. Implement `_apply_new_state(new_state: WeatherState) -> void` as the single emission point. This ensures the `equals()` guard and the signal emit always happen together with no duplication:
   ```gdscript
   func _apply_new_state(new_state: WeatherState) -> void:
       if _current_state != null and _current_state.equals(new_state):
           return   # no change — do not spam the signal
       _current_state = new_state
       weather_changed.emit(_current_state)
   ```
   WeatherOverlay connects to `weather_changed` and calls its own `apply_state()` — WeatherManager never reaches into the overlay directly, preserving the layer boundary.

7. Register WeatherManager in `project.godot`. Open the file and find the `[autoload]` section. Add the entry on the line immediately after FocusManager:
   ```
   WeatherManager="*res://autoloads/WeatherManager.gd"
   ```
   The `*` prefix tells Godot to enable the autoload. Load order in project.godot is top-to-bottom: WeatherManager must appear after FocusManager so that all preceding singletons (GardenManager, UserManager, ZoneManager, FocusManager) are available if WeatherManager ever needs to reference them in the future.

---

## Success Criteria

- Running the game with `use_mock = true` and `MockWeatherService.mock_condition = RAINY` causes `weather_changed` to emit once during `_ready()` with a state where `condition == RAINY`.
- Calling `_on_timer_timeout()` twice in succession with the same mock condition emits `weather_changed` only once (the second call is a no-op because `equals()` returns true).
- Setting `use_mock = false` with an empty endpoint in WeatherService causes no HTTP request and no crash — verified by checking Output for the push_warning message.
- Simulating a failed HTTP result (result != RESULT_SUCCESS) leaves `_current_state` unchanged — the overlay does not reset to default.
- `WeatherManager.get_current_state()` returns a non-null WeatherState immediately after scene load (before the first poll resolves), because `_ready()` initialises with `WeatherState.make_default()`.
- WeatherOverlay node is visible as a child of WeatherManager in the Remote scene tree inspector during play mode.
- Static analysis passes: `godot --headless --check-only --script res://autoloads/WeatherManager.gd` exits with no errors.

---

## Risks

- `preload("res://scenes/shared/WeatherOverlay.tscn")` in a `const` at the top of the script will cause a load error if the .tscn file does not exist yet when the project opens. Phase 4 must be completed before Phase 3 is testable end-to-end. During Phase 3 development, temporarily replace the preload with a placeholder and restore it after Phase 4.
- `_http.timeout = 5.0` requires Godot 4.1+. If the project is on an older 4.x patch, use a fallback Timer to manually cancel the request after 5 seconds instead.
- WeatherManager calling `_on_timer_timeout()` directly in `_ready()` triggers an immediate mock fetch. If `_overlay` is not yet ready when `weather_changed` emits, the overlay's `_on_weather_changed` handler will run before `_overlay._ready()` completes. This is safe because `add_child(_overlay)` above the emit call ensures `_ready()` on the overlay runs before control returns to WeatherManager — Godot calls child `_ready()` synchronously during `add_child` when the parent is already in the tree.
