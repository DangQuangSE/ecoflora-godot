class_name DailyTaskPanel
extends Control

const _TaskCardScene := preload("res://scenes/daily_task/TaskCard.tscn")

@onready var _card_list:  VBoxContainer = $Panel/VBox/ScrollMargin/Scroll/CardList
@onready var _daily_btn:  Button        = $Panel/VBox/TabMargin/TabRow/DailyBtn
@onready var _weekly_btn: Button        = $Panel/VBox/TabMargin/TabRow/WeeklyBtn
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

func show_panel(tab: int = DailyTask.DAILY) -> void:
	_current_tab = tab
	visible = true
	_rebuild_list(tab)

func _on_tasks_updated(_tasks: Array, _progress: Array) -> void:
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

func _on_claim_pressed(task_id: String) -> void:
	var card = _card_map.get(task_id, null)
	if card != null:
		card.disable_claim()
	TaskManager.claim_task_async(task_id)
	TaskManager.claim_result_received.connect(
		func(id: String, success: bool) -> void:
			if id != task_id:
				return
			if not success:
				var c = _card_map.get(task_id, null)
				if c != null:
					c.enable_claim(),
		CONNECT_ONE_SHOT
	)
