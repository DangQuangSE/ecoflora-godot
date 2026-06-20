class_name HUD
extends CanvasLayer

signal joystick_direction_changed(direction: Vector2)

@onready var _joystick: DynamicJoystick = $DynamicJoystick
@onready var _inv_btn: Button           = $InventoryButton
@onready var _inv_icon: TextureRect     = $InventoryButton/Icon
@onready var _inv_panel: InventoryPanelNode = $InventoryPanel
@onready var _tips_panel: TipsPanelNode     = $TipsPanel
@onready var _shop_panel: ShopScene         = $ShopScene
@onready var _task_panel: DailyTaskPanel    = $DailyTaskPanel
@onready var _settings_panel: SettingsPanel = $SettingsPanel
@onready var _vitality_bar: VitalityBar     = $VitalityBar
@onready var _selected_slot: Panel      = $SelectedItemSlot
@onready var _selected_icon: TextureRect = $SelectedItemSlot/SelectedIcon
@onready var _deselect_btn: Button      = $SelectedItemSlot/DeselectBtn
@onready var _harvest_btn: Button       = $HarvestButton
@onready var _shop_btn: Button          = $ShopButton
@onready var _task_btn: Button          = $TaskButton
@onready var _settings_btn: Button      = $SettingsButton
@onready var _edit_btn: Button          = $EditModeButton
@onready var _save_btn: Button          = $SaveButton
@onready var _recall_btn: Button        = $RecallDecoButton

var _recall_placement_id: String = ""
var _modal_open := false
var _edit_was_visible := false
var _save_was_visible := false

func _ready() -> void:
	_joystick.direction_changed.connect(_on_joystick_direction)
	_inv_btn.pressed.connect(_toggle_inventory)
	_deselect_btn.pressed.connect(InventoryManager.deselect)
	InventoryManager.item_selected.connect(_on_item_selected)
	_inv_icon.texture = preload("res://assets/icon/bag.png")
	_selected_slot.visible = false
	var harvest_icon := get_node_or_null("HarvestButton/Icon") as TextureRect
	if harvest_icon:
		harvest_icon.texture = preload("res://assets/icon/sickle.png")
	_harvest_btn.pressed.connect(InteractionManager.toggle_harvest_mode)
	InteractionManager.harvest_mode_changed.connect(_on_harvest_mode_changed)
	if _shop_btn:
		_shop_btn.pressed.connect(_open_shop)
		var shop_icon_path := "res://assets/icon/shop.png"
		if ResourceLoader.exists(shop_icon_path):
			var shop_node := _shop_btn.get_node_or_null("ShopIcon") as TextureRect
			if shop_node:
				shop_node.texture = load(shop_icon_path)
	if _task_btn:
		_task_btn.pressed.connect(_open_tasks)
		var task_icon_path := "res://assets/icon/task.png"
		if ResourceLoader.exists(task_icon_path):
			var task_node := _task_btn.get_node_or_null("TaskIcon") as TextureRect
			if task_node:
				task_node.texture = load(task_icon_path)
	if _settings_btn:
		_settings_btn.pressed.connect(_open_settings)
		var settings_icon_path := "res://assets/icon/setting.png"
		if ResourceLoader.exists(settings_icon_path):
			var settings_node := _settings_btn.get_node_or_null("SettingsIcon") as TextureRect
			if settings_node:
				settings_node.texture = load(settings_icon_path)
	_edit_btn.visible = false
	_save_btn.visible = false
	_recall_btn.visible = false
	_recall_btn.pressed.connect(_on_recall_pressed)
	DecoManager.deco_recalled.connect(func(_id: String) -> void: hide_recall_btn())
	if _vitality_bar:
		_vitality_bar.tips_pressed.connect(_toggle_tips)
	_inv_panel.visibility_changed.connect(_sync_modal_chrome)
	_shop_panel.visibility_changed.connect(_sync_modal_chrome)
	_task_panel.visibility_changed.connect(_sync_modal_chrome)
	_settings_panel.visibility_changed.connect(_sync_modal_chrome)
	_sync_modal_chrome()

func _on_joystick_direction(dir: Vector2) -> void:
	joystick_direction_changed.emit(dir)

func _toggle_inventory() -> void:
	if _inv_panel == null:
		return
	if _inv_panel.visible:
		if _inv_panel.has_method("hide_panel"):
			_inv_panel.call("hide_panel")
		else:
			_inv_panel.hide()
	else:
		_hide_tips_if_visible()
		_hide_shop_if_visible()
		_hide_tasks_if_visible()
		_hide_settings_if_visible()
		_inv_panel.show_panel()


func _toggle_tips() -> void:
	if _tips_panel == null:
		return
	if _tips_panel.visible:
		if _tips_panel.has_method("hide_panel"):
			_tips_panel.call("hide_panel")
		else:
			_tips_panel.hide()
	else:
		_hide_inventory_if_visible()
		_hide_shop_if_visible()
		_hide_tasks_if_visible()
		_hide_settings_if_visible()
		_tips_panel.show_panel()


func _hide_tips_if_visible() -> void:
	if _tips_panel == null or not _tips_panel.visible:
		return
	if _tips_panel.has_method("hide_panel"):
		_tips_panel.call("hide_panel")
	else:
		_tips_panel.hide()


func _hide_inventory_if_visible() -> void:
	if _inv_panel == null or not _inv_panel.visible:
		return
	if _inv_panel.has_method("hide_panel"):
		_inv_panel.call("hide_panel")
	else:
		_inv_panel.hide()


func _hide_shop_if_visible() -> void:
	if _shop_panel != null and _shop_panel.visible:
		_shop_panel.hide()


func _hide_tasks_if_visible() -> void:
	if _task_panel != null and _task_panel.visible:
		_task_panel.hide()


func _hide_settings_if_visible() -> void:
	if _settings_panel == null or not _settings_panel.visible:
		return
	if _settings_panel.has_method("hide_panel"):
		_settings_panel.call("hide_panel")
	else:
		_settings_panel.hide()

func _on_item_selected(item: InventoryItem) -> void:
	if item != null:
		_selected_icon.texture = ItemIconRegistry.get_icon(item.get_reference_id())
		_selected_slot.visible = true
	else:
		_selected_slot.visible = false
	if _inv_panel != null and _inv_panel.visible:
		if _inv_panel.has_method("hide_panel"):
			_inv_panel.call("hide_panel")
		else:
			_inv_panel.hide()

func _on_harvest_mode_changed(active: bool) -> void:
	_harvest_btn.modulate = Color(1.0, 0.75, 0.2, 1.0) if active else Color.WHITE

func open_shop(tab_idx: int = 0) -> void:
	if _shop_panel == null:
		return
	_hide_tips_if_visible()
	_hide_inventory_if_visible()
	_hide_tasks_if_visible()
	_hide_settings_if_visible()
	_shop_panel.show_panel(tab_idx)

func _open_shop() -> void:
	open_shop(0)

func _open_tasks() -> void:
	if _task_panel == null:
		return
	_hide_tips_if_visible()
	_hide_inventory_if_visible()
	_hide_shop_if_visible()
	_hide_settings_if_visible()
	_task_panel.show_panel(0)


func _open_settings() -> void:
	if _settings_panel == null:
		return
	_hide_tips_if_visible()
	_hide_inventory_if_visible()
	_hide_shop_if_visible()
	_hide_tasks_if_visible()
	_settings_panel.show_panel()

func _unhandled_input(event: InputEvent) -> void:
	if not _recall_btn.visible:
		return
	var is_press := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and (event as InputEventMouseButton).pressed)
	if not is_press:
		return
	var screen_pos: Vector2 = event.position
	var world_pos := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	if not DecoManager.has_deco_at(world_pos):
		hide_recall_btn()

func show_recall_btn(placement_id: String) -> void:
	_recall_placement_id = placement_id
	_recall_btn.visible = not _modal_open

func hide_recall_btn() -> void:
	_recall_placement_id = ""
	_recall_btn.visible = false

func _on_recall_pressed() -> void:
	if _recall_placement_id.is_empty():
		return
	var pid := _recall_placement_id
	hide_recall_btn()
	DecoManager.recall_deco_async(pid)

func _sync_modal_chrome() -> void:
	var next_modal_open: bool = (_inv_panel != null and _inv_panel.visible) \
		or (_shop_panel != null and _shop_panel.visible) \
		or (_task_panel != null and _task_panel.visible) \
		or (_settings_panel != null and _settings_panel.visible)
	if next_modal_open and not _modal_open:
		_edit_was_visible = _edit_btn.visible
		_save_was_visible = _save_btn.visible
	_modal_open = next_modal_open

	_joystick.visible = not _modal_open
	_inv_btn.visible = not _modal_open
	_harvest_btn.visible = not _modal_open
	if _shop_btn:
		_shop_btn.visible = not _modal_open
	if _task_btn:
		_task_btn.visible = not _modal_open
	if _settings_btn:
		_settings_btn.visible = not _modal_open
	if _vitality_bar:
		_vitality_bar.visible = not _modal_open

	if _modal_open:
		_edit_btn.visible = false
		_save_btn.visible = false
		_selected_slot.visible = false
		_recall_btn.visible = false
	else:
		_edit_btn.visible = _edit_was_visible
		_save_btn.visible = _save_was_visible
		_selected_slot.visible = InventoryManager.get_selected_item() != null
		_recall_btn.visible = not _recall_placement_id.is_empty()
