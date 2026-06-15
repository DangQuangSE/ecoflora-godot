class_name HUD
extends CanvasLayer

signal joystick_direction_changed(direction: Vector2)

@onready var _joystick: DynamicJoystick = $DynamicJoystick
@onready var _inv_btn: Button           = $InventoryButton
@onready var _inv_icon: TextureRect     = $InventoryButton/Icon
@onready var _inv_panel: InventoryPanelNode = $InventoryPanel
@onready var _shop_panel: ShopScene         = $ShopScene
@onready var _task_panel: Control           = $DailyTaskPanel
@onready var _selected_slot: Panel      = $SelectedItemSlot
@onready var _selected_icon: TextureRect = $SelectedItemSlot/SelectedIcon
@onready var _deselect_btn: Button      = $SelectedItemSlot/DeselectBtn
@onready var _harvest_btn: Button       = $HarvestButton
@onready var _shop_btn: Button          = $ShopButton
@onready var _task_btn: Button          = $TaskButton
@onready var _edit_btn: Button          = $EditModeButton
@onready var _save_btn: Button          = $SaveButton
@onready var _recall_btn: Button        = $RecallDecoButton

var _recall_placement_id: String = ""

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
	_edit_btn.visible = false
	_save_btn.visible = false
	_recall_btn.visible = false
	_recall_btn.pressed.connect(_on_recall_pressed)
	DecoManager.deco_recalled.connect(func(_id: String) -> void: hide_recall_btn())

func _on_joystick_direction(dir: Vector2) -> void:
	joystick_direction_changed.emit(dir)

func _toggle_inventory() -> void:
	if _inv_panel == null:
		return
	if _inv_panel.visible:
		_inv_panel.hide()
	else:
		_inv_panel.show_panel()

func _on_item_selected(item: InventoryItem) -> void:
	if item != null:
		_selected_icon.texture = ItemIconRegistry.get_icon(item.get_reference_id())
		_selected_slot.visible = true
	else:
		_selected_slot.visible = false
	if _inv_panel != null and _inv_panel.visible:
		_inv_panel.hide()

func _on_harvest_mode_changed(active: bool) -> void:
	_harvest_btn.modulate = Color(1.0, 0.75, 0.2, 1.0) if active else Color.WHITE

func open_shop(tab_idx: int = 0) -> void:
	if _shop_panel == null:
		return
	_shop_panel.show_panel(tab_idx)

func _open_shop() -> void:
	open_shop(0)

func _open_tasks() -> void:
	if _task_panel == null:
		return
	_task_panel.call("show_panel", 0)

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
	_recall_btn.visible = true

func hide_recall_btn() -> void:
	_recall_placement_id = ""
	_recall_btn.visible = false

func _on_recall_pressed() -> void:
	if _recall_placement_id.is_empty():
		return
	var pid := _recall_placement_id
	hide_recall_btn()
	DecoManager.recall_deco_async(pid)
