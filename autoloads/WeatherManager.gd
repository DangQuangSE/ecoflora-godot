extends Node

signal weather_changed(state: WeatherState)

const POLL_INTERVAL_SEC := 600.0
const OVERLAY_SCENE := preload("res://scenes/shared/WeatherOverlay.tscn")

@export var use_mock: bool = true
@export var mock_condition: WeatherState.Condition = WeatherState.Condition.SUNNY
@export var weather_endpoint: String = ""

var _current_state: WeatherState = null
var _request_in_flight: bool = false
var _timer: Timer
var _http: HTTPRequest
var _mock_service: MockWeatherService
var _weather_service: WeatherService
var _overlay: Node  # WeatherOverlay instance — typed as Node to avoid upward static import

func _ready() -> void:
	_mock_service = MockWeatherService.new()
	_weather_service = WeatherService.new()
	_weather_service.endpoint = weather_endpoint

	_timer = Timer.new()
	_timer.wait_time = POLL_INTERVAL_SEC
	_timer.autostart = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

	_http = HTTPRequest.new()
	_http.timeout = 5.0
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)

	_overlay = OVERLAY_SCENE.instantiate()
	assert(_overlay != null, "WeatherManager: failed to instantiate WeatherOverlay.tscn")
	add_child(_overlay)
	_overlay.call("apply_state", WeatherState.make_default())

	# Default state set before first poll so get_current_state() is never null
	_current_state = WeatherState.make_default()
	_on_timer_timeout()
	_timer.start()
	weather_changed.emit(_current_state)

func _exit_tree() -> void:
	if _request_in_flight:
		_http.cancel_request()
		_request_in_flight = false

func get_current_state() -> WeatherState:
	if _current_state == null:
		return WeatherState.make_default()
	return _current_state

func _on_timer_timeout() -> void:
	if use_mock:
		_mock_service.mock_condition = mock_condition
		_apply_new_state(_mock_service.get_state())
	else:
		if _request_in_flight:
			return
		if _weather_service.endpoint.is_empty():
			push_warning("WeatherManager: weather_endpoint not configured — skipping HTTP request")
			return
		var error := _http.request(_weather_service.endpoint)
		if error != OK:
			push_warning("WeatherManager: HTTPRequest.request() failed with error %d" % error)
			return
		_request_in_flight = true

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_in_flight = false
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
	var data: Variant = json.get_data()
	if not data is Dictionary:
		push_warning("WeatherManager: JSON root is not a Dictionary — keeping current state")
		return
	var typed_data: Dictionary = data
	var new_state: WeatherState = _weather_service.parse_response(typed_data)
	if new_state == null:
		push_warning("WeatherManager: parse_response returned null — keeping current state")
		return
	_apply_new_state(new_state)

func _apply_new_state(new_state: WeatherState) -> void:
	if _current_state != null and _current_state.equals(new_state):
		return
	_current_state = new_state
	_overlay.call("apply_state", new_state)  # duck-typed call avoids static import of scenes/ class
	weather_changed.emit(_current_state)
