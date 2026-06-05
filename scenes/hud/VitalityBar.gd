class_name VitalityBar
extends Control

# Required nodes in VitalityBar.tscn:
# - HeartIcon (TextureRect)
# - FillBar (ProgressBar)  min=0, max=21600 (6h in seconds)
# - CountdownLabel (Label)
# - ClaimButton (Button)

const COOLDOWN_SECONDS: int = 6 * 3600

@onready var _heart_icon: TextureRect = $HBoxContainer/HeartIcon
@onready var _fill_bar: ProgressBar   = $HBoxContainer/FillBar
@onready var _countdown: Label        = $HBoxContainer/CountdownLabel
@onready var _claim_btn: Button       = $HBoxContainer/ClaimButton

var _tick_timer: Timer

func _ready() -> void:
	var heart_path := "res://assets/icon/heart.png"
	if ResourceLoader.exists(heart_path):
		_heart_icon.texture = load(heart_path)
	UserManager.vitality_ready.connect(_on_vitality_ready)
	UserManager.vitality_claimed.connect(_on_vitality_claimed)
	_claim_btn.pressed.connect(_on_claim_pressed)

	_tick_timer = Timer.new()
	_tick_timer.wait_time = 1.0
	_tick_timer.autostart = true
	_tick_timer.one_shot = false
	_tick_timer.timeout.connect(_tick)
	add_child(_tick_timer)

	visibility_changed.connect(_on_visibility_changed)

	# Hydrate immediately rather than waiting 60s for the poll
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
		_fill_bar.value = COOLDOWN_SECONDS
		_countdown.text = "Sẵn sàng!"
		_claim_btn.disabled = false
	else:
		var now := int(Time.get_unix_time_from_system())
		var remaining := maxi(p.vitality_ready_at - now, 0)
		_fill_bar.value = COOLDOWN_SECONDS - remaining
		_countdown.text = _format_time(remaining)
		_claim_btn.disabled = true

func _tick() -> void:
	_refresh_display()

func _on_vitality_ready() -> void:
	_refresh_display()

func _on_vitality_claimed(_reward_type: String, _reward_amount: int) -> void:
	_refresh_display()
	_claim_btn.disabled = true

func _on_claim_pressed() -> void:
	_claim_btn.disabled = true
	UserManager.claim_vitality_async()

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
