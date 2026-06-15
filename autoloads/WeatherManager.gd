extends Node

signal weather_changed(state: WeatherState)

const POLL_INTERVAL_SEC := 600.0
const OVERLAY_SCENE := preload("res://scenes/shared/WeatherOverlay.tscn")

var _use_mock: bool = false
var _mock_condition: WeatherState.Condition = WeatherState.Condition.SUNNY
var _mock_is_day: bool = true

@export var use_mock: bool = true:
	get:
		return _use_mock
	set(value):
		if _use_mock == value:
			return
		_use_mock = value
		_on_mock_settings_changed()

@export var mock_condition: WeatherState.Condition = WeatherState.Condition.SUNNY:
	get:
		return _mock_condition
	set(value):
		if _mock_condition == value:
			return
		_mock_condition = value
		_on_mock_settings_changed()

@export var mock_is_day: bool = true:
	get:
		return _mock_is_day
	set(value):
		if _mock_is_day == value:
			return
		_mock_is_day = value
		_on_mock_settings_changed()

@export var weather_endpoint: String = ""

var _current_state: WeatherState = null
var _request_in_flight: bool = false
var _initialized: bool = false
var _timer: Timer
var _http: HTTPRequest
var _mock_service: MockWeatherService
var _weather_service: WeatherService
var _overlay: WeatherOverlay

func _ready() -> void:
	use_mock = UserManager.use_mock
	_mock_service = MockWeatherService.new()
	_weather_service = WeatherService.new()
	_weather_service.endpoint = _resolve_weather_endpoint()

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
	_overlay.apply_state(WeatherState.make_default())

	# Default state set before first poll so get_current_state() is never null
	_current_state = WeatherState.make_default()
	_initialized = true
	_on_timer_timeout()
	_timer.start()
	weather_changed.emit(_current_state)

	UserManager.login_succeeded.connect(_on_login_succeeded)

func _on_login_succeeded() -> void:
	_on_timer_timeout()

func _on_mock_settings_changed() -> void:
	if not _initialized:
		return
	if use_mock:
		_mock_service.mock_condition = mock_condition
		_mock_service.mock_is_day = mock_is_day
		_apply_new_state(_mock_service.get_state())
	else:
		_on_timer_timeout()

func _exit_tree() -> void:
	if _request_in_flight:
		_http.cancel_request()
		_request_in_flight = false

func set_overlay_visible(visible: bool) -> void:
	if _overlay != null:
		_overlay.visible = visible

func get_current_state() -> WeatherState:
	if _current_state == null:
		return WeatherState.make_default()
	return _current_state

func _resolve_weather_endpoint() -> String:
	if not weather_endpoint.is_empty():
		return weather_endpoint
	return UserManager.base_url + "/api/weather/current"

func _on_timer_timeout() -> void:
	if use_mock:
		_mock_service.mock_condition = mock_condition
		_mock_service.mock_is_day = mock_is_day
		_apply_new_state(_mock_service.get_state())
	else:
		if _request_in_flight:
			return
		if _weather_service.endpoint.is_empty():
			push_warning("WeatherManager: weather_endpoint not configured — skipping HTTP request")
			return
		var headers := PackedStringArray([])
		var auth := UserManager.get_auth_header()
		if not auth.is_empty():
			headers.append(auth)
		var error := _http.request(_weather_service.endpoint, headers)
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
	_overlay.apply_state(new_state)
	weather_changed.emit(_current_state)
