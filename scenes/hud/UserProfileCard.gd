class_name UserProfileCard
extends CanvasLayer

const _CARD_H_SMALL: float  = 1050.0
const _CARD_H_LARGE: float  = 1050.0
const _CARD_W: float = 700.0
const _OPEN_SLIDE_OFFSET: float = 20.0

const _CHAR_THUMBS: Array[String] = [
	"res://assets/characters/char_0_thumb.png",
	"res://assets/characters/char_1_thumb.png",
]
const _CHAR_FRAME_PATHS: Array[String] = [
	"res://assets/characters/char_0.tres",
	"res://assets/characters/char_1.tres",
]
const _CHARACTER_NAMES: Array[String] = [
	"Mặc định",
	"Nhân vật 1",
]

@onready var _dimmer: ColorRect             = $Dimmer
@onready var _card: Panel                   = $Card
@onready var _close_btn: Button             = $Card/CloseBtn
@onready var _logout_btn: Button            = $Card/BottomRow/LogoutBtn
@onready var _bottom_row: HBoxContainer     = $Card/BottomRow
@onready var _content: VBoxContainer        = $Card/Content
@onready var _avatar_frame: Panel           = $Card/Content/AvatarRow/AvatarFrame
@onready var _avatar_image: TextureRect     = $Card/Content/AvatarRow/AvatarFrame/AvatarImage
@onready var _username_row: HBoxContainer   = $Card/Content/AvatarRow/InfoCol/UsernameRow
@onready var _username_label: Label         = $Card/Content/AvatarRow/InfoCol/UsernameRow/UsernameLabel
@onready var _edit_btn: Button              = $Card/Content/AvatarRow/InfoCol/UsernameRow/EditBtn
@onready var _rename_row: HBoxContainer     = $Card/Content/AvatarRow/InfoCol/RenameRow
@onready var _rename_edit: LineEdit         = $Card/Content/AvatarRow/InfoCol/RenameRow/RenameEdit
@onready var _rename_save_btn: Button       = $Card/Content/AvatarRow/InfoCol/RenameRow/RenameSaveBtn
@onready var _rename_cancel_btn: Button     = $Card/Content/AvatarRow/InfoCol/RenameRow/RenameCancelBtn
@onready var _level_badge: Label            = $Card/Content/AvatarRow/InfoCol/LevelBadge
@onready var _join_date_label: Label        = $Card/Content/AvatarRow/InfoCol/JoinDateLabel
@onready var _level_value: Label            = $Card/Content/RowLevel/LevelValue
@onready var _xp_value: Label               = $Card/Content/RowXP/XPValue
@onready var _harvest_value: Label          = $Card/Content/RowHarvest/HarvestValue
@onready var _streak_value: Label           = $Card/Content/RowStreak/StreakValue
@onready var _flowers_value: Label          = $Card/Content/RowFlowers/FlowersValue
@onready var _char_card: Button             = $Card/Content/CharacterSection/CharacterCard
@onready var _char_preview: TextureRect     = $Card/Content/CharacterSection/CharacterCard/HBox/Tex
@onready var _char_name_label: Label        = $Card/Content/CharacterSection/CharacterCard/HBox/Info/NameLabel
@onready var _edit_char_btn: Button         = $Card/Content/CharacterSection/CharacterCard/HBox/EditCharBtn
@onready var _char_picker: VBoxContainer    = $Card/CharacterPicker
@onready var _char_picker_grid: GridContainer = $Card/CharacterPicker/Grid
@onready var _confirm_char_btn: Button      = $Card/CharacterPicker/ButtonRow/ConfirmBtn
@onready var _cancel_char_btn: Button       = $Card/CharacterPicker/ButtonRow/CancelBtn
@onready var _avatar_picker: VBoxContainer  = $Card/AvatarPicker
@onready var _picker_grid: GridContainer    = $Card/AvatarPicker/Grid
@onready var _confirm_btn: Button           = $Card/AvatarPicker/ButtonRow/ConfirmBtn
@onready var _cancel_btn: Button            = $Card/AvatarPicker/ButtonRow/CancelBtn

var _is_closing: bool = false
var _pending_idx: int = -1
var _pending_char_idx: int = -1

func _ready() -> void:
	visible = false
	_close_btn.pressed.connect(close)
	_logout_btn.pressed.connect(_on_logout_pressed)
	_dimmer.gui_input.connect(_on_dimmer_input)
	_avatar_frame.gui_input.connect(_on_avatar_frame_input)
	_confirm_btn.pressed.connect(_on_confirm_avatar)
	_cancel_btn.pressed.connect(_collapse_card)
	_edit_btn.pressed.connect(_enter_rename_mode)
	_char_card.pressed.connect(_on_edit_char_pressed)
	_edit_char_btn.pressed.connect(_on_edit_char_pressed)
	_confirm_char_btn.pressed.connect(_on_confirm_character)
	_cancel_char_btn.pressed.connect(_collapse_card)
	_rename_save_btn.pressed.connect(_on_rename_save)
	_rename_cancel_btn.pressed.connect(_exit_rename_mode)
	_rename_edit.text_submitted.connect(func(_t: String) -> void: _on_rename_save())
	_load_picker_icons()
	for i in 7:
		var btn := _picker_grid.get_child(i) as Button
		if btn:
			btn.pressed.connect(_on_avatar_selected.bind(i))
	_load_char_buttons()
	for i in _char_picker_grid.get_child_count():
		var btn := _char_picker_grid.get_child(i) as Button
		if btn:
			btn.pressed.connect(_on_char_selected.bind(i))
	UserManager.profile_updated.connect(_refresh_data)
	UserManager.character_changed.connect(_refresh_character_section)

func _exit_tree() -> void:
	if UserManager.profile_updated.is_connected(_refresh_data):
		UserManager.profile_updated.disconnect(_refresh_data)
	if UserManager.character_changed.is_connected(_refresh_character_section):
		UserManager.character_changed.disconnect(_refresh_character_section)

func open() -> void:
	_is_closing = false
	_card.scale = Vector2.ONE
	_card.pivot_offset = Vector2(_CARD_W * 0.5, _CARD_H_SMALL * 0.5)
	_card.offset_left = -(_CARD_W * 0.5)
	_card.offset_right = _CARD_W * 0.5
	_card.offset_top = -(_CARD_H_SMALL * 0.5) + _OPEN_SLIDE_OFFSET
	_card.offset_bottom = _CARD_H_SMALL * 0.5 + _OPEN_SLIDE_OFFSET
	_refresh_data()
	visible = true
	_card.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "modulate:a", 1.0, 0.16)
	tween.tween_property(_card, "offset_top", -(_CARD_H_SMALL * 0.5), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_card, "offset_bottom", _CARD_H_SMALL * 0.5, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func close() -> void:
	if _is_closing:
		return
	_is_closing = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "modulate:a", 0.0, 0.14)
	tween.tween_property(_card, "offset_top", _card.offset_top + _OPEN_SLIDE_OFFSET, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_card, "offset_bottom", _card.offset_bottom + _OPEN_SLIDE_OFFSET, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if not is_instance_valid(self):
		return
	queue_free()

func _refresh_data() -> void:
	var p := UserManager.get_profile()
	var display_name := p.get_display_name()
	if display_name.is_empty():
		return
	_username_label.text  = display_name
	_level_badge.text     = "Lv. " + str(p.level)
	_join_date_label.text = _format_join_date(p.join_date)
	_level_value.text     = str(p.level)
	_xp_value.text        = str(p.total_xp_earned)
	_harvest_value.text   = str(p.harvest_count)
	_streak_value.text    = str(p.login_streak) + " ngày"
	_flowers_value.text   = str(_count_flowers())
	_refresh_avatar(p.avatar_index)
	_refresh_character_section()

func _refresh_avatar(idx: int) -> void:
	var path := _avatar_path(idx)
	if ResourceLoader.exists(path):
		_avatar_image.texture = load(path)
	else:
		_avatar_image.texture = null

func _count_flowers() -> int:
	var count := 0
	for item in InventoryManager.get_inventory().items:
		if item.category == InventoryItem.Category.SEED \
		or item.category == InventoryItem.Category.HARVEST_PRODUCT:
			count += item.quantity
	return count

func _load_char_buttons() -> void:
	for i in _char_picker_grid.get_child_count():
		var btn := _char_picker_grid.get_child(i) as Button
		if not btn:
			continue
		var tex := btn.get_node_or_null("Margin/Tex") as TextureRect
		if tex:
			tex.texture = _character_thumb_texture(i)

func _character_thumb_texture(idx: int) -> Texture2D:
	if idx < _CHAR_THUMBS.size() and ResourceLoader.exists(_CHAR_THUMBS[idx]):
		return load(_CHAR_THUMBS[idx]) as Texture2D
	if idx >= _CHAR_FRAME_PATHS.size() or not ResourceLoader.exists(_CHAR_FRAME_PATHS[idx]):
		return null
	var frames := load(_CHAR_FRAME_PATHS[idx]) as SpriteFrames
	if frames == null or not frames.has_animation(&"idle_down"):
		return null
	if frames.get_frame_count(&"idle_down") <= 0:
		return null
	return frames.get_frame_texture(&"idle_down", 0)

func _refresh_character_section(_idx: int = -1) -> void:
	var equipped := _idx if _idx >= 0 else UserManager.get_character_index()
	_char_preview.texture = _character_thumb_texture(equipped)
	if equipped >= 0 and equipped < _CHARACTER_NAMES.size():
		_char_name_label.text = _CHARACTER_NAMES[equipped]
	else:
		_char_name_label.text = "Nhân vật " + str(equipped)
	
	var owned := UserManager.get_owned_characters()
	for i in _char_picker_grid.get_child_count():
		var btn := _char_picker_grid.get_child(i) as Button
		if not btn:
			continue
		btn.disabled = not owned.has(i)
		var badge := btn.get_node_or_null("EquippedBadge") as Label
		if badge:
			badge.visible = (i == equipped)

func _on_char_selected(idx: int) -> void:
	if not UserManager.is_character_owned(idx):
		return
	_pending_char_idx = idx
	_update_char_picker_highlight()

func _on_edit_char_pressed() -> void:
	_open_char_picker()

func _open_char_picker() -> void:
	if _avatar_picker.visible:
		return
	_pending_char_idx = UserManager.get_character_index()
	_update_char_picker_highlight()
	_expand_char_picker()

func _on_confirm_character() -> void:
	if _pending_char_idx >= 0 and _pending_char_idx != UserManager.get_character_index():
		if UserManager.is_character_owned(_pending_char_idx):
			UserManager.set_character_async(_pending_char_idx)
	_collapse_card()

func _expand_char_picker() -> void:
	_content.visible = false
	_bottom_row.visible = false
	_char_picker.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "offset_top", -(_CARD_H_LARGE * 0.5), 0.1)
	tween.tween_property(_card, "offset_bottom", _CARD_H_LARGE * 0.5, 0.1)

func _update_char_picker_highlight() -> void:
	for i in _char_picker_grid.get_child_count():
		var btn := _char_picker_grid.get_child(i) as Button
		if btn:
			var border := btn.get_node_or_null("SelectedBorder") as Panel
			if border:
				border.visible = (i == _pending_char_idx)

func _load_picker_icons() -> void:
	for i in 7:
		var btn := _picker_grid.get_child(i) as Button
		if not btn:
			continue
		var tex := btn.get_node_or_null("Margin/Tex") as TextureRect
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

func _enter_rename_mode() -> void:
	if _avatar_picker.visible:
		return
	_username_row.visible = false
	_rename_edit.text = UserManager.get_profile().get_display_name()
	_rename_row.visible = true
	_rename_edit.grab_focus()
	_rename_edit.select_all()

func _exit_rename_mode() -> void:
	_rename_row.visible = false
	_username_row.visible = true

func _on_rename_save() -> void:
	var new_name := _rename_edit.text.strip_edges()
	_exit_rename_mode()
	if not new_name.is_empty() and new_name != UserManager.get_profile().get_display_name():
		UserManager.set_name_async(new_name)

func _on_avatar_frame_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
	or (event is InputEventScreenTouch and event.pressed):
		if _avatar_picker.visible:
			_collapse_card()
		else:
			_pending_idx = UserManager.get_profile().avatar_index
			_update_picker_highlight()
			_expand_card()

func _on_avatar_selected(idx: int) -> void:
	_pending_idx = idx
	_update_picker_highlight()

func _on_confirm_avatar() -> void:
	if _pending_idx >= 0:
		UserManager.set_avatar_async(_pending_idx)
	_collapse_card()

func _expand_card() -> void:
	_content.visible = false
	_bottom_row.visible = false
	_avatar_picker.visible = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "offset_top", -(_CARD_H_LARGE * 0.5), 0.1)
	tween.tween_property(_card, "offset_bottom", _CARD_H_LARGE * 0.5, 0.1)

func _collapse_card() -> void:
	_avatar_picker.visible = false
	_char_picker.visible = false
	_content.visible = true
	_bottom_row.visible = true
	_refresh_avatar(UserManager.get_profile().avatar_index)
	_refresh_character_section()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_card, "offset_top", -(_CARD_H_SMALL * 0.5), 0.1)
	tween.tween_property(_card, "offset_bottom", _CARD_H_SMALL * 0.5, 0.1)

func _update_picker_highlight() -> void:
	for i in 7:
		var btn := _picker_grid.get_child(i) as Button
		if btn:
			var border := btn.get_node_or_null("SelectedBorder") as Panel
			if border:
				border.visible = (i == _pending_idx)

func _on_dimmer_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) \
	or (event is InputEventScreenTouch and event.pressed):
		close()

func _on_logout_pressed() -> void:
	close()
	UserManager.logout()
