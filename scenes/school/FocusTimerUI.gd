extends CanvasLayer

const _ITEM_NAME_VI: Dictionary = {
	"watering can": "Bình tưới",
	"fertilizer":   "Phân bón",
	"pesticide":    "Thuốc trừ sâu",
}

@export var max_pauses: int = 2
@export var min_duration_minutes: int = 10
@export var max_duration_minutes: int = 120
@export var default_duration_minutes: int = 25
@export var reward_threshold_minutes: int = 25

@onready var _setup_panel: Control   = $Panel/SetupPanel
@onready var _running_panel: Control = $Panel/RunningPanel
@onready var _result_panel: Control  = $Panel/ResultPanel

@onready var _duration_slider: HSlider = $Panel/SetupPanel/SetupBox/DurationSlider
@onready var _duration_label: Label    = $Panel/SetupPanel/SetupBox/DurationLabel
@onready var _start_btn: Button        = $Panel/SetupPanel/SetupBox/StartButton
@onready var _close_btn: Button        = $Panel/SetupPanel/SetupBox/CloseButton

@onready var _countdown_label: Label  = $Panel/RunningPanel/RunningBox/CountdownLabel
@onready var _violation_label: Label  = $Panel/RunningPanel/RunningBox/ViolationLabel
@onready var _pauses_label: Label     = $Panel/RunningPanel/RunningBox/PausesLabel
@onready var _pause_btn: Button       = $Panel/RunningPanel/RunningBox/PauseButton
@onready var _cancel_btn: Button      = $Panel/RunningPanel/RunningBox/CancelButton

@onready var _result_label: Label = $Panel/ResultPanel/ResultBox/ResultLabel
@onready var _return_btn: Button  = $Panel/ResultPanel/ResultBox/ReturnButton

func _ready() -> void:
	_duration_slider.value_changed.connect(_on_slider_changed)
	_start_btn.pressed.connect(_on_start_pressed)
	_close_btn.pressed.connect(queue_free)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_return_btn.pressed.connect(_on_return_pressed)

	FocusManager.tick.connect(_on_tick)
	FocusManager.violation_updated.connect(_on_violation_updated)
	FocusManager.session_paused.connect(_on_session_paused)
	FocusManager.session_resumed.connect(_on_session_resumed)
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
		_refresh_pause_ui(FocusManager.get_pause_count())
	else:
		_setup_panel.visible = true
		_running_panel.visible = false
		_result_panel.visible = false
		_duration_slider.min_value = min_duration_minutes
		_duration_slider.max_value = max_duration_minutes
		_duration_slider.step = 5
		_duration_slider.value = default_duration_minutes
		_duration_label.text = "%d phút" % default_duration_minutes

func _exit_tree() -> void:
	if FocusManager.tick.is_connected(_on_tick):
		FocusManager.tick.disconnect(_on_tick)
	if FocusManager.violation_updated.is_connected(_on_violation_updated):
		FocusManager.violation_updated.disconnect(_on_violation_updated)
	if FocusManager.session_paused.is_connected(_on_session_paused):
		FocusManager.session_paused.disconnect(_on_session_paused)
	if FocusManager.session_resumed.is_connected(_on_session_resumed):
		FocusManager.session_resumed.disconnect(_on_session_resumed)
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

func _on_pause_pressed() -> void:
	if FocusManager.is_paused():
		FocusManager.resume_session()
	else:
		FocusManager.pause_session()

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
		_result_label.text = "Không có phần thưởng\n(cần ít nhất %d phút)" % reward_threshold_minutes
		return
	var lines: PackedStringArray = []
	for entry: Variant in items:
		if not entry is Dictionary:
			continue
		var raw_name: String = str((entry as Dictionary).get("itemName", "?"))
		var display_name: String = _ITEM_NAME_VI.get(raw_name.to_lower(), raw_name)
		lines.append("%s x%d" % [display_name, int(entry.get("quantity", 0))])
	_result_label.text = "Phần thưởng:\n" + "\n".join(lines)

func _on_session_paused(pauses_used: int) -> void:
	_pause_btn.text = "Tiếp tục"
	_refresh_pause_ui(pauses_used)

func _on_session_resumed() -> void:
	_pause_btn.text = "Tạm dừng"

func _refresh_pause_ui(pauses_used: int) -> void:
	var remaining := max_pauses - pauses_used
	_pauses_label.text = "Còn %d lần tạm dừng" % remaining
	_pause_btn.disabled = remaining <= 0 and not FocusManager.is_paused()

func _on_session_failed() -> void:
	_running_panel.visible = false
	_result_panel.visible = true
	_result_label.text = "-20 XP cho tất cả cây"

func _on_return_pressed() -> void:
	SceneTransition.fade_to("res://scenes/school/SchoolScene.tscn")
	queue_free()
