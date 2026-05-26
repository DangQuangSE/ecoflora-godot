class_name UserProfileCard
extends CanvasLayer

@onready var _dimmer: ColorRect    = $Dimmer
@onready var _card: Panel          = $Card
@onready var _level_label: Label   = $Card/Content/LevelLabel
@onready var _xp_label: Label      = $Card/Content/XPLabel
@onready var _harvest_label: Label = $Card/Content/HarvestLabel
@onready var _close_btn: Button    = $Card/CloseBtn

var _is_closing: bool = false

func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(close)
	_dimmer.gui_input.connect(_on_dimmer_input)

func open() -> void:
	_is_closing = false
	var p := UserManager.get_profile()
	_level_label.text   = "Level: %d" % p.level
	_xp_label.text      = "Tổng XP: %d" % p.total_xp_earned
	_harvest_label.text = "Lần thu hoạch: %d" % p.harvest_count
	visible = true
	_card.position.y = 320.0
	var tween := create_tween()
	tween.tween_property(_card, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	var tween := create_tween()
	tween.tween_property(_card, "position:y", 320.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if not is_instance_valid(self):
		return
	visible = false
	_is_closing = false

func _on_dimmer_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		close()
