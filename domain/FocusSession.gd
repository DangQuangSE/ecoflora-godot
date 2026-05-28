class_name FocusSession
extends RefCounted

var duration_seconds: int = 0
var elapsed_seconds: float = 0.0
var violation_count: int = 0
var max_violations: int = 3

func _init(duration_sec: int, max_v: int) -> void:
	duration_seconds = duration_sec
	max_violations = max_v

func get_remaining_seconds() -> int:
	return maxi(0, duration_seconds - int(elapsed_seconds))

func get_minutes_focused() -> int:
	return int(elapsed_seconds / 60.0)

func is_completed() -> bool:
	return elapsed_seconds >= float(duration_seconds)

func is_failed() -> bool:
	return violation_count >= max_violations
