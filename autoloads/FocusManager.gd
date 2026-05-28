extends Node

signal session_completed(minutes_focused: int)
signal session_failed()
signal session_cancelled()
signal tick(remaining_seconds: int)
signal violation_updated(count: int)

enum State { IDLE, ACTIVE, COMPLETED, FAILED }

const MAX_VIOLATIONS := 3

@export var bypass_violation_detection: bool = false

var _state: State = State.IDLE
var _session: FocusSession = null

func _ready() -> void:
	set_process(false)
	session_completed.connect(GardenManager._on_focus_session_completed)
	session_failed.connect(GardenManager._on_focus_session_failed)

func get_state() -> State:
	return _state

func get_violation_count() -> int:
	return _session.violation_count if _session != null else 0

func start_session(duration_sec: int) -> void:
	if _state != State.IDLE:
		push_warning("FocusManager.start_session: called in state %d, expected IDLE" % _state)
		return
	_session = FocusSession.new(duration_sec, MAX_VIOLATIONS)
	_set_state(State.ACTIVE)

func cancel_session() -> void:
	if _state not in [State.ACTIVE, State.IDLE]:
		return
	var was_active := _state == State.ACTIVE
	_set_state(State.IDLE)
	_session = null
	if was_active:
		session_cancelled.emit()

func _process(delta: float) -> void:
	if _session == null:
		return
	_session.elapsed_seconds += delta
	tick.emit(_session.get_remaining_seconds())
	if _session.is_completed():
		var minutes := _session.get_minutes_focused()
		_set_state(State.COMPLETED)
		session_completed.emit(minutes)

func _notification(what: int) -> void:
	if bypass_violation_detection:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED and _state == State.ACTIVE:
		_session.violation_count += 1
		violation_updated.emit(_session.violation_count)
		if _session.is_failed():
			_set_state(State.FAILED)
			session_failed.emit()

func _set_state(new_state: State) -> void:
	if _state == new_state:
		return
	_state = new_state
	set_process(new_state == State.ACTIVE)
