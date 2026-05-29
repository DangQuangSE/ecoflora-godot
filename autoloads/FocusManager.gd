extends Node

signal session_completed(minutes_focused: int)
signal session_failed()
signal session_cancelled()
signal tick(remaining_seconds: int)
signal violation_updated(count: int)

enum State { IDLE, ACTIVE, COMPLETED, FAILED }

const MAX_VIOLATIONS := 3

@export var use_mock: bool = true
@export var bypass_violation_detection: bool = false

const _FocusServiceScript = preload("res://services/FocusService.gd")

var _state: State = State.IDLE
var _session: FocusSession = null

var _be_session_id: String = ""
var _create_in_flight: bool = false
var _terminal_in_flight: bool = false
var _pending_terminal_state: String = ""  # "complete" | "fail" | ""
var _pending_terminal_strikes: int = 0
var _http_create: HTTPRequest    # dedicated to create_async
var _http_terminal: HTTPRequest  # dedicated to complete_async / fail_async
var _focus_service: FocusService = null  # null in mock mode

func _ready() -> void:
	set_process(false)
	session_completed.connect(GardenManager._on_focus_session_completed)
	session_failed.connect(GardenManager._on_focus_session_failed)
	if not use_mock:
		_http_create = HTTPRequest.new()
		_http_create.timeout = 10.0
		add_child(_http_create)
		_http_terminal = HTTPRequest.new()
		_http_terminal.timeout = 10.0
		add_child(_http_terminal)
		_focus_service = _FocusServiceScript.new(_http_create, _http_terminal)
	if use_mock and UserManager.is_logged_in():
		push_warning("FocusManager: use_mock=true but real token present")

func get_state() -> State:
	return _state

func get_violation_count() -> int:
	return _session.violation_count if _session != null else 0

## Coroutine — starts the session locally immediately, then async-POSTs to BE.
## Callers that need the BE session id set must await this.
func start_session(duration_sec: int) -> void:
	if _state != State.IDLE:
		push_warning("FocusManager.start_session: called in state %d, expected IDLE" % _state)
		return
	_session = FocusSession.new(duration_sec, MAX_VIOLATIONS)
	_set_state(State.ACTIVE)
	if not use_mock:
		_create_in_flight = true
		var token: String = UserManager.get_access_token()
		var minutes: int = max(1, duration_sec / 60)
		var result: Dictionary = await _focus_service.create_async(UserManager.base_url, token, minutes)
		_create_in_flight = false
		if not result.is_empty():
			var new_id: String = result.get("id", "")
			if _state == State.ACTIVE:
				_be_session_id = new_id
			elif not _pending_terminal_state.is_empty():
				# Race: session ended while POST was in-flight — fire terminal call now
				_be_session_id = new_id
				_fire_terminal_async(_pending_terminal_state, _pending_terminal_strikes)
				_pending_terminal_state = ""
				_pending_terminal_strikes = 0
			# else: session was cancelled — discard id

func cancel_session() -> void:
	if _state not in [State.ACTIVE, State.IDLE]:
		return
	var was_active := _state == State.ACTIVE
	_set_state(State.IDLE)
	_session = null
	_be_session_id = ""
	_pending_terminal_state = ""
	_pending_terminal_strikes = 0
	if was_active:
		session_cancelled.emit()

func _process(delta: float) -> void:
	if _session == null:
		return
	_session.elapsed_seconds += delta
	tick.emit(_session.get_remaining_seconds())
	if _session.is_completed():
		var minutes := _session.get_minutes_focused()
		var strikes := _session.violation_count
		_session = null
		_set_state(State.COMPLETED)
		session_completed.emit(minutes)
		if not use_mock:
			if _create_in_flight:
				_pending_terminal_state = "complete"
				_pending_terminal_strikes = strikes
			elif not _be_session_id.is_empty():
				_fire_terminal_async("complete", strikes)
			else:
				push_warning("FocusManager: session completed but no BE id to sync (POST may have failed)")

func _notification(what: int) -> void:
	if bypass_violation_detection:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED and _state == State.ACTIVE:
		if _session == null:
			return
		_session.violation_count += 1
		violation_updated.emit(_session.violation_count)
		if _session.is_failed():
			var strikes := _session.violation_count
			_session = null
			_set_state(State.FAILED)
			session_failed.emit()
			if not use_mock:
				if _create_in_flight:
					_pending_terminal_state = "fail"
					_pending_terminal_strikes = strikes
				elif not _be_session_id.is_empty():
					# Fire-and-forget coroutine — _notification cannot await
					_fire_terminal_async("fail", strikes)

# Fires the complete or fail PATCH against BE as a fire-and-forget coroutine.
# Captures _be_session_id into a local before clearing it to prevent double-fire.
func _fire_terminal_async(state: String, strikes: int) -> void:
	if _terminal_in_flight or _focus_service == null:
		return
	_terminal_in_flight = true
	var id := _be_session_id
	_be_session_id = ""
	if id.is_empty():
		push_warning("FocusManager: skipping terminal call — no BE session id")
		_terminal_in_flight = false
		return
	var token: String = UserManager.get_access_token()
	var ok: bool
	if state == "complete":
		ok = await _focus_service.complete_async(UserManager.base_url, token, id, strikes)
	else:
		ok = await _focus_service.fail_async(UserManager.base_url, token, id, strikes)
	if not ok:
		push_warning("FocusManager: BE terminal sync failed for session %s (state=%s)" % [id, state])
	_terminal_in_flight = false

func _exit_tree() -> void:
	if _create_in_flight and _http_create != null:
		_http_create.cancel_request()
	if _terminal_in_flight and _http_terminal != null:
		_http_terminal.cancel_request()

func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	set_process(new_state == State.ACTIVE)
