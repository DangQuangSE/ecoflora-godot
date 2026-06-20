extends Node

signal tasks_updated(tasks: Array, progress: Array)
signal claim_result_received(task_id: String, success: bool)

@export var use_mock: bool = false

const _SAVE_PATH := "user://daily_task_progress.json"
const _DailyTaskServiceScript = preload("res://services/DailyTaskService.gd")

var _tasks:            Array[DailyTask] = []
var _progress:         Dictionary       = {}   # task_id -> TaskProgress
var _delta_acc:        float            = 0.0
var _last_reset_epoch: int              = 0
var _claim_in_flight:  bool             = false
var _progress_dirty:   bool             = false
var _heartbeat_in_flight: bool          = false

var _svc:            DailyTaskService
var _http_fetch:     HTTPRequest
var _http_claim:     HTTPRequest
var _http_heartbeat: HTTPRequest

func _ready() -> void:
	_svc = _DailyTaskServiceScript.new()
	set_process(false)
	_load_cache()

	if not use_mock:
		_http_fetch = HTTPRequest.new()
		_http_fetch.timeout = 15.0
		add_child(_http_fetch)
		_http_claim = HTTPRequest.new()
		_http_claim.timeout = 15.0
		add_child(_http_claim)
		_http_heartbeat = HTTPRequest.new()
		_http_heartbeat.timeout = 15.0
		add_child(_http_heartbeat)

	GardenManager.care_completed.connect(_on_care_completed)
	GardenManager.harvest_completed.connect(_on_harvest_completed)
	FocusManager.session_completed.connect(_on_session_completed)
	UserManager.login_succeeded.connect(_on_login_succeeded)
	UserManager.login_required.connect(_on_logout)

func _process(delta: float) -> void:
	_delta_acc += minf(delta, 2.0)
	if _delta_acc >= 60.0:
		_delta_acc -= 60.0
		_on_progress_increment(DailyTask.ONLINE_TIME, "", 1)
		if not use_mock:
			_send_online_heartbeat()
	if _progress_dirty:
		_progress_dirty = false
		_save_progress()

func _on_login_succeeded() -> void:
	set_process(true)
	if use_mock:
		if _tasks.is_empty():
			_tasks = DailyTaskService.build_offline_fallback()
		tasks_updated.emit(_tasks, _progress.values())
		return
	var result := await _svc.fetch_async(_http_fetch, UserManager.base_url, UserManager.get_access_token())
	if result.is_empty():
		if _tasks.is_empty():
			_tasks = DailyTaskService.build_offline_fallback()
		tasks_updated.emit(_tasks, _progress.values())
		return
	var server_time: int = int(result.get("server_time", 0))
	if server_time > 0:
		_maybe_reset_progress(server_time)
		_last_reset_epoch = server_time
	var _raw_t: Variant = result.get("tasks", null)
	var server_tasks: Array[DailyTask] = []
	if _raw_t is Array:
		server_tasks.assign(_raw_t)
	var _raw_p: Variant = result.get("progress", null)
	var server_progress: Array[TaskProgress] = []
	if _raw_p is Array:
		server_progress.assign(_raw_p)
	if not server_tasks.is_empty():
		_tasks = server_tasks
	elif _tasks.is_empty():
		_tasks = DailyTaskService.build_offline_fallback()
	for sp: TaskProgress in server_progress:
		_progress[sp.task_id] = sp
	_save_progress()
	tasks_updated.emit(_tasks, _progress.values())

func _on_logout() -> void:
	set_process(false)
	_save_progress()
	_tasks            = []
	_progress         = {}
	_delta_acc        = 0.0
	_last_reset_epoch = 0
	_claim_in_flight  = false

func _send_online_heartbeat() -> void:
	if _heartbeat_in_flight:
		return
	_heartbeat_in_flight = true
	await _svc.record_online_time_async(_http_heartbeat, UserManager.base_url, UserManager.get_access_token(), 1)
	_heartbeat_in_flight = false

func _on_care_completed(_plot_id: String, action_type: int) -> void:
	var subtype: String = ""
	match action_type:
		0: subtype = "water"
		1: subtype = "fertilize"
		2: subtype = "pesticide"
	_on_progress_increment(DailyTask.GARDEN_CARE, subtype, 1)

func _on_harvest_completed(_plot_id: String, _product_id: String) -> void:
	_on_progress_increment(DailyTask.HARVEST, "", 1)

func _on_session_completed(_minutes_focused: int) -> void:
	_on_progress_increment(DailyTask.FOCUS_SESSION, "", 1)

func _on_progress_increment(task_type: int, subtype: String, amount: int) -> void:
	var changed := false
	for task: DailyTask in _tasks:
		if task.type != task_type:
			continue
		if not subtype.is_empty() and not task.action_subtype.is_empty():
			if task.action_subtype != subtype:
				continue
		var prog: TaskProgress = _progress.get(task.id, null)
		if prog == null:
			prog = TaskProgress.new()
			prog.task_id = task.id
			_progress[task.id] = prog
		if prog.claimed or prog.progress >= task.target:
			continue
		prog.progress = mini(prog.progress + amount, task.target)
		changed = true
	if changed:
		_progress_dirty = true
		tasks_updated.emit(_tasks, _progress.values())

func claim_task_async(task_id: String) -> void:
	if _claim_in_flight:
		return
	_claim_in_flight = true
	if use_mock:
		await get_tree().process_frame
		var mock_prog: TaskProgress = _progress.get(task_id, null)
		if mock_prog != null:
			mock_prog.claimed = true
		_save_progress()
		tasks_updated.emit(_tasks, _progress.values())
		claim_result_received.emit(task_id, true)
		_claim_in_flight = false
		return
	var task: DailyTask = _find_task(task_id)
	if task == null:
		claim_result_received.emit(task_id, false)
		_claim_in_flight = false
		return
	var result := await _svc.claim_async(_http_claim, UserManager.base_url, UserManager.get_access_token(), task_id)
	if result.is_empty():
		claim_result_received.emit(task_id, false)
		_claim_in_flight = false
		return
	var new_currency: Variant = result.get("newCurrencyTotal", null)
	if new_currency != null:
		UserManager.update_currency(int(new_currency))
	var new_xp: Variant    = result.get("newUserXP", null)
	var new_level: Variant = result.get("newUserLevel", null)
	if new_xp != null and new_level != null:
		UserManager.apply_server_xp(int(new_xp), int(new_level))
	var reward_item_id:  String = str(result.get("rewardItemId", ""))
	var reward_item_qty: int    = int(result.get("rewardItemQty", 0))
	if not reward_item_id.is_empty() and reward_item_qty > 0:
		InventoryManager.add_reward_item(reward_item_id, "", reward_item_qty)
	var prog: TaskProgress = _progress.get(task_id, null)
	if prog != null:
		prog.claimed = true
	_save_progress()
	tasks_updated.emit(_tasks, _progress.values())
	claim_result_received.emit(task_id, true)
	_claim_in_flight = false

func get_tasks() -> Array[DailyTask]:
	return _tasks

func get_progress(task_id: String) -> TaskProgress:
	return _progress.get(task_id, null)

func _find_task(task_id: String) -> DailyTask:
	for t: DailyTask in _tasks:
		if t.id == task_id:
			return t
	return null

func _maybe_reset_progress(server_time: int) -> void:
	if _last_reset_epoch == 0:
		return
	var old_daily  := _get_daily_period_start(_last_reset_epoch)
	var new_daily  := _get_daily_period_start(server_time)
	var old_weekly := _get_weekly_period_start(_last_reset_epoch)
	var new_weekly := _get_weekly_period_start(server_time)
	if new_weekly > old_weekly:
		_progress = {}
		return
	if new_daily > old_daily:
		for task: DailyTask in _tasks:
			if task.cycle == DailyTask.DAILY:
				_progress.erase(task.id)

func _get_daily_period_start(unix_time: int) -> int:
	return floori(float(unix_time) / 86400.0) * 86400

func _get_weekly_period_start(unix_time: int) -> int:
	var days := floori(float(unix_time) / 86400.0)
	# 1970-01-01 = Thursday; offset +3 to make Monday = 0
	var days_since_monday := (days + 3) % 7
	return (days - days_since_monday) * 86400

func _load_cache() -> void:
	var file := FileAccess.open(_SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var data: Variant = json.get_data()
	if not data is Dictionary:
		return
	_last_reset_epoch = int((data as Dictionary).get("last_reset_epoch", 0))
	var progress_arr: Variant = (data as Dictionary).get("progress", [])
	if not progress_arr is Array:
		return
	for item: Variant in progress_arr:
		if item is Dictionary:
			var p := TaskProgress.from_dict(item as Dictionary)
			_progress[p.task_id] = p

func _save_progress() -> void:
	var arr: Array = []
	for p: TaskProgress in _progress.values():
		arr.append(p.to_dict())
	var file := FileAccess.open(_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("TaskManager._save_progress: cannot open %s" % _SAVE_PATH)
		return
	file.store_string(JSON.stringify({"last_reset_epoch": _last_reset_epoch, "progress": arr}))
