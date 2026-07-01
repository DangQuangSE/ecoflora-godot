class_name DailyTaskService
extends RefCounted

# Stable task IDs — must match the BE seed in docs/daily-task/task-stable-ids.md
const TASK_IDS: Dictionary = {
	"water_daily":        "a0000000-da11-0001-0001-000000000001",
	"fertilize_daily":    "a0000000-da11-0001-0001-000000000002",
	"harvest_daily":      "a0000000-da11-0001-0001-000000000003",
	"focus_daily":        "a0000000-da11-0001-0001-000000000004",
	"online_daily":       "a0000000-da11-0001-0001-000000000005",
	"care_weekly":        "a0000000-da11-0002-0001-000000000001",
	"harvest_weekly":     "a0000000-da11-0002-0001-000000000002",
	"focus_weekly":       "a0000000-da11-0002-0001-000000000003",
}

# Parses GET /api/daily-tasks response arrays into typed domain objects.
# Returns { "tasks": Array[DailyTask], "progress": Array[TaskProgress], "server_time": int }
func parse_tasks(task_arr: Array, progress_arr: Array) -> Dictionary:
	var tasks: Array[DailyTask] = []
	for item: Variant in task_arr:
		if not item is Dictionary:
			continue
		tasks.append(DailyTask.from_dict(item as Dictionary))

	var progress: Array[TaskProgress] = []
	for item: Variant in progress_arr:
		if not item is Dictionary:
			continue
		progress.append(TaskProgress.from_dict(item as Dictionary))

	return {"tasks": tasks, "progress": progress, "server_time": 0}

# GET /api/daily-tasks — returns parsed result dict or {} on failure.
func fetch_async(http: HTTPRequest, base_url: String, token: String) -> Dictionary:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token,
	])
	var raw: Array = await HttpHelper.request_with_retry_async(http, base_url + "/api/daily-tasks", HTTPClient.METHOD_GET, headers)
	var err: int = raw[0]
	if err != OK:
		push_warning("DailyTaskService.fetch_async: request error %d" % err)
		return {}
	var status: int            = raw[1]
	var bytes: PackedByteArray = raw[3]
	if status == 401:
		push_warning("DailyTaskService.fetch_async: 401 after retry — giving up")
		return {}
	if status != 200:
		push_warning("DailyTaskService.fetch_async: HTTP %d" % status)
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		push_warning("DailyTaskService.fetch_async: JSON parse error")
		return {}
	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return {}
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	if not data is Dictionary:
		return {}
	var d: Dictionary = data as Dictionary
	var task_arr: Variant     = d.get("tasks", [])
	var progress_arr: Variant = d.get("progress", [])
	var server_time: Variant  = d.get("serverTimeUtc", 0)
	var result := parse_tasks(
		task_arr if task_arr is Array else [],
		progress_arr if progress_arr is Array else []
	)
	result["server_time"] = int(server_time) if server_time is int or server_time is float else 0
	return result

# POST /api/daily-tasks/{task_id}/claim
# Returns response dict { newCurrencyTotal, newUserXP, newUserLevel, rewardItemId, rewardItemQty }
# or {} on failure. 401 returns {} — caller must check and call UserManager.handle_401().
func claim_async(http: HTTPRequest, base_url: String, token: String, task_id: String) -> Dictionary:
	var url := "%s/api/daily-tasks/%s/claim" % [base_url, task_id]
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token,
	])
	var raw: Array = await HttpHelper.request_with_retry_async(http, url, HTTPClient.METHOD_POST, headers, "")
	var err: int = raw[0]
	if err != OK:
		push_warning("DailyTaskService.claim_async: request error %d" % err)
		return {}
	var status: int            = raw[1]
	var bytes: PackedByteArray = raw[3]
	if status == 401:
		push_warning("DailyTaskService.claim_async: 401 after retry")
		return {}
	if status != 200:
		push_warning("DailyTaskService.claim_async: HTTP %d" % status)
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		push_warning("DailyTaskService.claim_async: JSON parse error")
		return {}
	var envelope: Variant = json.get_data()
	if not envelope is Dictionary:
		return {}
	var data: Variant = HttpHelper.unwrap_envelope(envelope)
	if not data is Dictionary:
		return {}
	return data as Dictionary

# POST /api/daily-tasks/online-heartbeat — reports elapsed online minutes so
# ONLINE_TIME progress is tracked server-side instead of only in local cache.
func record_online_time_async(http: HTTPRequest, base_url: String, token: String, minutes: int) -> bool:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % token,
	])
	var body := JSON.stringify({"minutes": minutes})
	var raw: Array = await HttpHelper.request_with_retry_async(http, base_url + "/api/daily-tasks/online-heartbeat", HTTPClient.METHOD_POST, headers, body)
	var err: int = raw[0]
	if err != OK:
		push_warning("DailyTaskService.record_online_time_async: request error %d" % err)
		return false
	var status: int = raw[1]
	if status != 200:
		push_warning("DailyTaskService.record_online_time_async: HTTP %d" % status)
		return false
	return true

# Returns display-only placeholder tasks for offline mode.
# Reward values are zero — tasks are non-claimable until a real GET succeeds.
static func build_offline_fallback() -> Array[DailyTask]:
	var result: Array[DailyTask] = []
	var definitions: Array = [
		{ "id": TASK_IDS["water_daily"],     "title": "Tưới cây 3 lần",           "type": DailyTask.GARDEN_CARE,   "action_subtype": "water",      "target": 3, "cycle": DailyTask.DAILY  },
		{ "id": TASK_IDS["fertilize_daily"], "title": "Bón phân 2 lần",            "type": DailyTask.GARDEN_CARE,   "action_subtype": "fertilize",  "target": 2, "cycle": DailyTask.DAILY  },
		{ "id": TASK_IDS["harvest_daily"],   "title": "Thu hoạch 2 bông hoa",      "type": DailyTask.HARVEST,       "action_subtype": "",           "target": 2, "cycle": DailyTask.DAILY  },
		{ "id": TASK_IDS["focus_daily"],     "title": "Hoàn thành 1 phiên Focus",  "type": DailyTask.FOCUS_SESSION, "action_subtype": "",           "target": 1, "cycle": DailyTask.DAILY  },
		{ "id": TASK_IDS["online_daily"],    "title": "Online 30 phút",            "type": DailyTask.ONLINE_TIME,   "action_subtype": "",           "target": 30, "cycle": DailyTask.DAILY },
		{ "id": TASK_IDS["care_weekly"],     "title": "Chăm sóc cây 10 lần",       "type": DailyTask.GARDEN_CARE,   "action_subtype": "",           "target": 10, "cycle": DailyTask.WEEKLY },
		{ "id": TASK_IDS["harvest_weekly"],  "title": "Thu hoạch 5 bông hoa",      "type": DailyTask.HARVEST,       "action_subtype": "",           "target": 5, "cycle": DailyTask.WEEKLY },
		{ "id": TASK_IDS["focus_weekly"],    "title": "Hoàn thành 3 phiên Focus",  "type": DailyTask.FOCUS_SESSION, "action_subtype": "",           "target": 3, "cycle": DailyTask.WEEKLY },
	]
	for raw: Dictionary in definitions:
		var t := DailyTask.new()
		t.id             = str(raw["id"])
		t.title          = str(raw["title"])
		t.type           = int(raw["type"])
		t.action_subtype = str(raw["action_subtype"])
		t.target         = int(raw["target"])
		t.cycle          = int(raw["cycle"])
		result.append(t)
	return result
