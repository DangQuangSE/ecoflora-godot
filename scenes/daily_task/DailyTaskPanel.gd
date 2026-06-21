class_name DailyTaskPanel
extends Control

const _TaskCardScene := preload("res://scenes/daily_task/TaskCard.tscn")

@onready var _card_list:  VBoxContainer = $Panel/VBox/ScrollMargin/Scroll/CardList
@onready var _daily_btn:  Button        = $Panel/VBox/TabMargin/TabRow/DailyBtn
@onready var _weekly_btn: Button        = $Panel/VBox/TabMargin/TabRow/WeeklyBtn
@onready var _daily_dot:  Control       = $Panel/VBox/TabMargin/TabRow/DailyBtn/ClaimDot
@onready var _weekly_dot: Control       = $Panel/VBox/TabMargin/TabRow/WeeklyBtn/ClaimDot
@onready var _close_btn:  Button        = $Panel/VBox/Header/HeaderRow/CloseBtn
@onready var _bg_dimmer:  ColorRect     = $BGDimmer

var _current_tab: int       = DailyTask.DAILY
var _card_map:    Dictionary = {}  # task_id -> Node (TaskCard)

func _ready() -> void:
	visible = false
	TaskManager.tasks_updated.connect(_on_tasks_updated)
	_daily_btn.pressed.connect(func() -> void: _rebuild_list(DailyTask.DAILY))
	_weekly_btn.pressed.connect(func() -> void: _rebuild_list(DailyTask.WEEKLY))
	_close_btn.pressed.connect(func() -> void: visible = false)
	_bg_dimmer.gui_input.connect(_on_backdrop_input)
	_sync_tab_claim_dots()

func show_panel(tab: int = DailyTask.DAILY) -> void:
	_current_tab = tab
	visible = true
	_rebuild_list(tab)

func _on_tasks_updated(_tasks: Array, _progress: Array) -> void:
	_sync_tab_claim_dots()
	if visible:
		_rebuild_list(_current_tab)

func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			visible = false
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		visible = false

func _rebuild_list(cycle: int) -> void:
	_current_tab = cycle
	_daily_btn.button_pressed = (cycle == DailyTask.DAILY)
	_weekly_btn.button_pressed = (cycle == DailyTask.WEEKLY)
	_sync_tab_claim_dots()
	_card_map    = {}
	for child in _card_list.get_children():
		child.queue_free()
	var tasks: Array[DailyTask] = TaskManager.get_tasks()
	for task: DailyTask in tasks:
		if task.cycle != cycle:
			continue
		var prog: TaskProgress = TaskManager.get_progress(task.id)
		var card = _TaskCardScene.instantiate()
		card.task_id         = task.id
		card.title_text      = task.title
		card.target          = task.target
		card.progress        = prog.progress if prog != null else 0
		card.is_claimed      = prog.claimed  if prog != null else false
		card.reward_currency = task.reward_currency
		card.reward_xp       = task.reward_xp
		card.reward_item_id  = task.reward_item_id
		card.reward_item_qty = task.reward_item_qty
		var task_id := task.id
		card.claim_pressed.connect(func() -> void: _on_claim_pressed(task_id))
		_card_list.add_child(card)
		_card_map[task.id] = card

func _sync_tab_claim_dots() -> void:
	if _daily_dot != null:
		_daily_dot.visible = _has_claimable_task_for_cycle(DailyTask.DAILY)
	if _weekly_dot != null:
		_weekly_dot.visible = _has_claimable_task_for_cycle(DailyTask.WEEKLY)

func _has_claimable_task_for_cycle(cycle: int) -> bool:
	for task: DailyTask in TaskManager.get_tasks():
		if task.cycle != cycle:
			continue
		var prog: TaskProgress = TaskManager.get_progress(task.id)
		if prog != null and not prog.claimed and prog.is_complete(task.target):
			return true
	return false

func _on_claim_pressed(task_id: String) -> void:
	var card = _card_map.get(task_id, null)
	if card != null:
		card.disable_claim()
	var task_title := _task_title(task_id)
	TaskManager.claim_task_async(task_id)
	var on_claim_result := func(id: String, success: bool) -> void:
		if id != task_id:
			return
		var msg := "Nhận thưởng thất bại. Vui lòng thử lại."
		var duration := 2.6
		if success:
			msg = "Đã nhận thưởng: %s" % task_title
			duration = 2.2
		Toast.show_message(self, msg, duration)
		if not success:
			var c = _card_map.get(task_id, null)
			if c != null:
				c.enable_claim()
	TaskManager.claim_result_received.connect(on_claim_result, CONNECT_ONE_SHOT)

func _task_title(task_id: String) -> String:
	for task: DailyTask in TaskManager.get_tasks():
		if task.id == task_id:
			return task.title
	return "nhiệm vụ"
