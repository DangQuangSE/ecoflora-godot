class_name TaskCard
extends PanelContainer

signal claim_pressed

@export var title_text: String = ""
@export var progress:   int    = 0
@export var target:     int    = 1
@export var is_claimed: bool   = false

var task_id: String = ""

@onready var _title:    Label       = $Margin/HBox/Info/Title
@onready var _bar:      ProgressBar = $Margin/HBox/Info/ProgressRow/Bar
@onready var _prog_lbl: Label       = $Margin/HBox/Info/ProgressRow/ProgressLabel
@onready var _btn:      Button      = $Margin/HBox/ClaimButton

func _ready() -> void:
	_title.text    = title_text
	_bar.max_value = target
	_bar.value     = progress
	_prog_lbl.text = "%d / %d" % [progress, target]
	_update_btn_state()
	_btn.pressed.connect(func() -> void: claim_pressed.emit())

func disable_claim() -> void:
	_btn.disabled = true
	_btn.text     = "Đang xử lý..."

func enable_claim() -> void:
	_btn.disabled = false
	_btn.text     = "Nhận"

func _update_btn_state() -> void:
	if is_claimed:
		_btn.text = "Đã nhận"
		_btn.disabled = true
		modulate  = Color(0.75, 0.75, 0.75, 1.0)
	elif progress >= target:
		_btn.text     = "Nhận"
		_btn.disabled = false
	else:
		_btn.text     = "Chưa xong"
		_btn.disabled = true
