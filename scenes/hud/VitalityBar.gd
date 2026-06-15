class_name VitalityBar
extends Control

signal tips_pressed

const COOLDOWN_SECONDS: int = 6 * 3600

@onready var _heart_icon: TextureRect = $VBoxContainer/HeartIcon
@onready var _tips_btn: Button        = $VBoxContainer/TipsButton
@onready var _tips_icon: TextureRect  = $VBoxContainer/TipsButton/Icon
@onready var _countdown: Label        = $VBoxContainer/CountdownLabel

var _tick_timer: Timer
var _pulse_tween: Tween

func _ready() -> void:
	var heart_path := "res://assets/icon/heart.png"
	if ResourceLoader.exists(heart_path):
		_heart_icon.texture = load(heart_path)
	_heart_icon.pivot_offset = Vector2(16.0, 16.0)

	var tip_path := "res://assets/icon/tip_icon_v2.png"
	if ResourceLoader.exists(tip_path):
		_tips_icon.texture = load(tip_path)
	_tips_btn.pressed.connect(func() -> void: tips_pressed.emit())

	UserManager.vitality_ready.connect(_on_vitality_ready)
	UserManager.vitality_claimed.connect(_on_vitality_claimed)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.autostart = true
	_tick_timer.one_shot = false
	_tick_timer.timeout.connect(_tick)
	add_child(_tick_timer)

	visibility_changed.connect(_on_visibility_changed)
	UserManager.request_vitality_status_async()
	_refresh_display()

func _exit_tree() -> void:
	if UserManager.vitality_ready.is_connected(_on_vitality_ready):
		UserManager.vitality_ready.disconnect(_on_vitality_ready)
	if UserManager.vitality_claimed.is_connected(_on_vitality_claimed):
		UserManager.vitality_claimed.disconnect(_on_vitality_claimed)

func _refresh_display() -> void:
	var p := UserManager.get_profile()
	if p.is_vitality_ready():
		_countdown.text = "Sẵn sàng!"
		mouse_filter = MOUSE_FILTER_STOP
		_start_pulse()
	else:
		var now := int(Time.get_unix_time_from_system())
		var remaining := maxi(p.vitality_ready_at - now, 0)
		_countdown.text = _format_time(remaining)
		mouse_filter = MOUSE_FILTER_IGNORE
		_stop_pulse()

func _start_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_heart_icon, "scale", Vector2(1.28, 1.28), 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_heart_icon, "scale", Vector2(1.0, 1.0), 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_heart_icon.scale = Vector2.ONE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed or (event as InputEventMouseButton).button_index != MOUSE_BUTTON_LEFT:
			return
	elif event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return
	else:
		return
	get_viewport().set_input_as_handled()
	mouse_filter = MOUSE_FILTER_IGNORE
	_stop_pulse()
	UserManager.claim_vitality_async()

func _on_vitality_ready() -> void:
	_refresh_display()

func _on_vitality_claimed(reward_type: String, reward_amount: int) -> void:
	_refresh_display()
	_show_reward_popup(reward_type, reward_amount)

func _show_reward_popup(reward_type: String, reward_amount: int) -> void:
	var msg := "Bạn nhận được: %s x%d" % [reward_type, reward_amount]
	BaseDialog.show_alert(self, "🎉 Chúc mừng!", msg, "Đồng ý")

func _tick() -> void:
	_refresh_display()

func _on_visibility_changed() -> void:
	if _tick_timer == null:
		return
	if visible:
		_tick_timer.start()
		_refresh_display()
	else:
		_tick_timer.stop()

func _format_time(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	var s := seconds % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]
