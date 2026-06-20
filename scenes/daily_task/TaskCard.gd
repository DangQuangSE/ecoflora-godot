class_name TaskCard
extends PanelContainer

signal claim_pressed

@export var title_text:      String = ""
@export var progress:        int    = 0
@export var target:          int    = 1
@export var is_claimed:      bool   = false
@export var reward_currency: int    = 0
@export var reward_xp:       int    = 0
@export var reward_item_id:  String = ""
@export var reward_item_qty: int    = 0

var task_id: String = ""

@onready var _title:       Label        = $Margin/HBox/Info/Title
@onready var _reward_row:  HBoxContainer = $Margin/HBox/Info/RewardRow
@onready var _xp_reward:   PanelContainer = $Margin/HBox/Info/RewardRow/XpReward
@onready var _xp_value:    Label        = $Margin/HBox/Info/RewardRow/XpReward/Content/Value
@onready var _coin_reward: PanelContainer = $Margin/HBox/Info/RewardRow/CoinReward
@onready var _coin_value:  Label        = $Margin/HBox/Info/RewardRow/CoinReward/Content/Value
@onready var _item_reward: Label        = $Margin/HBox/Info/RewardRow/ItemRewardLabel
@onready var _bar:         ProgressBar  = $Margin/HBox/Info/ProgressRow/Bar
@onready var _prog_lbl:    Label        = $Margin/HBox/Info/ProgressRow/ProgressLabel
@onready var _btn:         Button       = $Margin/HBox/ClaimButton

func _ready() -> void:
	_title.text    = title_text
	_refresh_rewards()
	_bar.max_value = target
	_bar.value     = progress
	_prog_lbl.text = "%d / %d" % [progress, target]
	_update_btn_state()
	_btn.pressed.connect(func() -> void: claim_pressed.emit())

func _refresh_rewards() -> void:
	_xp_reward.visible = reward_xp > 0
	_xp_value.text = "+%d" % reward_xp
	_coin_reward.visible = reward_currency > 0
	_coin_value.text = "+%d" % reward_currency
	_item_reward.visible = not reward_item_id.is_empty() and reward_item_qty > 0
	_item_reward.text = "+%d vật phẩm" % reward_item_qty
	_reward_row.visible = _xp_reward.visible or _coin_reward.visible or _item_reward.visible

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
