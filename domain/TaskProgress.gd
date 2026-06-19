class_name TaskProgress
extends RefCounted

var task_id:      String = ""
var progress:     int    = 0
var claimed:      bool   = false
var period_start: int    = 0  # Unix epoch of current period boundary (7AM UTC+7)

func is_complete(target: int) -> bool:
	return progress >= target

func to_dict() -> Dictionary:
	return {
		"task_id":      task_id,
		"progress":     progress,
		"claimed":      claimed,
		"period_start": period_start,
	}

static func from_dict(d: Dictionary) -> TaskProgress:
	var p := TaskProgress.new()
	p.task_id = str(d.get("task_id", d.get("taskId", "")))
	p.progress = int(d.get("progress", 0))
	p.claimed  = bool(d.get("claimed", false))

	var raw_period: Variant = d.get("period_start", d.get("periodStart", 0))
	if raw_period is String and not (raw_period as String).is_empty():
		p.period_start = int(Time.get_unix_time_from_datetime_string(raw_period))
	else:
		p.period_start = int(raw_period)

	return p
