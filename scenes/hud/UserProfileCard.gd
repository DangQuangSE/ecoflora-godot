class_name UserProfileCard
extends CanvasLayer

@onready var _dimmer: ColorRect          = $Dimmer
@onready var _card: Panel                = $Card
@onready var _close_btn: Button          = $Card/CloseBtn
@onready var _avatar_image: TextureRect  = $Card/Content/AvatarRow/AvatarFrame/AvatarImage
@onready var _username_label: Label      = $Card/Content/AvatarRow/InfoCol/UsernameLabel
@onready var _level_badge: Label         = $Card/Content/AvatarRow/InfoCol/LevelBadge
@onready var _join_date_label: Label     = $Card/Content/AvatarRow/InfoCol/JoinDateLabel
@onready var _level_value: Label         = $Card/Content/RowLevel/LevelValue
@onready var _xp_value: Label            = $Card/Content/RowXP/XPValue
@onready var _harvest_value: Label       = $Card/Content/RowHarvest/HarvestValue
@onready var _streak_value: Label        = $Card/Content/RowStreak/StreakValue
@onready var _flowers_value: Label       = $Card/Content/RowFlowers/FlowersValue
@onready var _toggle_picker_btn: Button  = $Card/Content/TogglePickerBtn
@onready var _avatar_picker: PanelContainer = $Card/AvatarPicker
@onready var _picker_row: HBoxContainer  = $Card/AvatarPicker/PickerRow

var _is_closing: bool = false

func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(close)
	_dimmer.gui_input.connect(_on_dimmer_input)
	_toggle_picker_btn.pressed.connect(_on_toggle_picker_pressed)
	_load_picker_icons()
	var connected_count := 0
	for i in 7:
		var btn := _picker_row.get_child(i) as Button
		if btn:
			btn.pressed.connect(_on_avatar_selected.bind(i))
			connected_count += 1
		else:
			push_warning("UserProfileCard._ready: picker child %d is not a Button (got %s)" % [i, str(_picker_row.get_child(i))])
	push_warning("UserProfileCard._ready: connected %d picker buttons, picker_row children=%d" % [connected_count, _picker_row.get_child_count()])
	UserManager.profile_updated.connect(_refresh_data)

func _exit_tree() -> void:
	if UserManager.profile_updated.is_connected(_refresh_data):
		UserManager.profile_updated.disconnect(_refresh_data)

func open() -> void:
	_is_closing = false
	_refresh_data()
	visible = true
	_card.modulate.a = 0.0
	_card.position.y = 24.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "modulate:a", 1.0, 0.16)
	tween.tween_property(_card, "position:y", 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "modulate:a", 0.0, 0.14)
	tween.tween_property(_card, "position:y", 24.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if not is_instance_valid(self):
		return
	queue_free()

func _refresh_data() -> void:
	var p := UserManager.get_profile()
	if p.username.is_empty():
		return
	_username_label.text  = p.username
	_level_badge.text     = "Lv. " + str(p.level)
	_join_date_label.text = _format_join_date(p.join_date)
	_level_value.text     = str(p.level)
	_xp_value.text        = str(p.total_xp_earned)
	_harvest_value.text   = str(p.harvest_count)
	_streak_value.text    = str(p.login_streak) + " ngay"
	_flowers_value.text   = str(_count_flowers())
	_refresh_avatar(p.avatar_index)

func _refresh_avatar(idx: int) -> void:
	var path := _avatar_path(idx)
	var exists := ResourceLoader.exists(path)
	push_warning("UserProfileCard._refresh_avatar: idx=%d path=%s exists=%s" % [idx, path, str(exists)])
	if exists:
		_avatar_image.texture = load(path)
	else:
		_avatar_image.texture = null

func _count_flowers() -> int:
	var count := 0
	for item in InventoryManager.get_inventory().items:
		if item.category == InventoryItem.Category.HARVEST_PRODUCT \
		and item.harvest_product_id.begins_with("harvest_"):
			count += item.quantity
	return count

func _load_picker_icons() -> void:
	for i in 7:
		var btn := _picker_row.get_child(i) as Button
		if not btn:
			continue
		var tex := btn.get_child(0) as TextureRect
		if not tex:
			continue
		var path := _avatar_path(i)
		if ResourceLoader.exists(path):
			tex.texture = load(path)

func _format_join_date(raw: String) -> String:
	if raw.is_empty() or raw == "null":
		return ""
	var dt := Time.get_datetime_dict_from_datetime_string(raw, true)
	if dt.is_empty():
		return ""
	return "Tham gia: %02d/%02d/%04d" % [int(dt["day"]), int(dt["month"]), int(dt["year"])]

static func _avatar_path(idx: int) -> String:
	return "res://assets/avartar/avartar_%d.png" % (idx + 1)

func _on_toggle_picker_pressed() -> void:
	_avatar_picker.visible = not _avatar_picker.visible
	_toggle_picker_btn.text = "Thu gon" if _avatar_picker.visible else "Doi avatar"

func _on_avatar_selected(idx: int) -> void:
	push_warning("UserProfileCard._on_avatar_selected: idx=%d" % idx)
	_avatar_picker.visible = false
	_toggle_picker_btn.text = "Doi avatar"
	UserManager.set_avatar_async(idx)  # fire-and-forget: optimistic UI, profile_updated handles refresh

func _on_dimmer_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		close()
