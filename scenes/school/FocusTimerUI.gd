extends CanvasLayer

@onready var _setup_panel: Control   = $Panel/SetupPanel
@onready var _running_panel: Control = $Panel/RunningPanel
@onready var _result_panel: Control  = $Panel/ResultPanel

@onready var _duration_slider: HSlider = $Panel/SetupPanel/SetupBox/DurationSlider
@onready var _duration_label: Label    = $Panel/SetupPanel/SetupBox/DurationLabel
@onready var _start_btn: Button        = $Panel/SetupPanel/SetupBox/StartButton

@onready var _countdown_label: Label = $Panel/RunningPanel/RunningBox/CountdownLabel
@onready var _violation_label: Label = $Panel/RunningPanel/RunningBox/ViolationLabel
@onready var _cancel_btn: Button     = $Panel/RunningPanel/RunningBox/CancelButton

@onready var _result_label: Label = $Panel/ResultPanel/ResultBox/ResultLabel
@onready var _return_btn: Button  = $Panel/ResultPanel/ResultBox/ReturnButton

func _ready() -> void:
	_duration_slider.value_changed.connect(_on_slider_changed)
	_start_btn.pressed.connect(_on_start_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_return_btn.pressed.connect(_on_return_pressed)

	FocusManager.tick.connect(_on_tick)
	FocusManager.violation_updated.connect(_on_violation_updated)
	FocusManager.session_completed.connect(_on_session_completed, CONNECT_ONE_SHOT)
	FocusManager.session_failed.connect(_on_session_failed, CONNECT_ONE_SHOT)
	FocusManager.session_cancelled.connect(queue_free, CONNECT_ONE_SHOT)
	if not FocusManager.session_reward_received.is_connected(_on_reward_received):
		FocusManager.session_reward_received.connect(_on_reward_received)

	if FocusManager.get_state() == FocusManager.State.ACTIVE:
		_setup_panel.visible = false
		_running_panel.visible = true
		_result_panel.visible = false
		_violation_label.text = "Vi phạm: %d / %d" % [FocusManager.get_violation_count(), FocusManager.MAX_VIOLATIONS]
	else:
		_setup_panel.visible = true
		_running_panel.visible = false
		_result_panel.visible = false
		_duration_slider.min_value = 5
		_duration_slider.max_value = 120
		_duration_slider.step = 5
		_duration_slider.value = 25
		_duration_label.text = "25 phút"

func _exit_tree() -> void:
	if FocusManager.tick.is_connected(_on_tick):
		FocusManager.tick.disconnect(_on_tick)
	if FocusManager.violation_updated.is_connected(_on_violation_updated):
		FocusManager.violation_updated.disconnect(_on_violation_updated)
	if FocusManager.session_reward_received.is_connected(_on_reward_received):
		FocusManager.session_reward_received.disconnect(_on_reward_received)

func _on_slider_changed(value: float) -> void:
	_duration_label.text = "%d phút" % int(value)

func _on_start_pressed() -> void:
	var duration_sec := int(_duration_slider.value) * 60
	FocusManager.start_session(duration_sec)
	_setup_panel.visible = false
	_running_panel.visible = true
	var total_min := int(_duration_slider.value)
	_countdown_label.text = "%02d:00" % total_min
	_violation_label.text = "Vi phạm: 0 / %d" % FocusManager.MAX_VIOLATIONS

func _on_cancel_pressed() -> void:
	FocusManager.cancel_session()

func _on_tick(remaining_seconds: int) -> void:
	var mins := remaining_seconds / 60
	var secs := remaining_seconds % 60
	_countdown_label.text = "%02d:%02d" % [mins, secs]

func _on_violation_updated(count: int) -> void:
	_violation_label.text = "Vi phạm: %d / %d" % [count, FocusManager.MAX_VIOLATIONS]

func _on_session_completed(_minutes: int) -> void:
	_running_panel.visible = false
	_result_panel.visible = true
	_result_label.text = "Đang nhận phần thưởng..."

func _on_reward_received(items: Array) -> void:
	if items.is_empty():
		_result_label.text = "Không có phần thưởng\n(cần ít nhất 25 phút)"
		return
	var lines: PackedStringArray = []
	for entry: Variant in items:
		if not entry is Dictionary:
			continue
		lines.append("%s x%d" % [str(entry.get("itemName", "?")), int(entry.get("quantity", 0))])
	_result_label.text = "Phần thưởng:\n" + "\n".join(lines)

func _on_session_failed() -> void:
	_running_panel.visible = false
	_result_panel.visible = true
	_result_label.text = "-20 XP cho tất cả cây"

func _on_return_pressed() -> void:
	SceneTransition.fade_to("res://scenes/school/SchoolScene.tscn")
	queue_free()
