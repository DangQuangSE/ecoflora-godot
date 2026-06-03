class_name HUD
extends CanvasLayer

signal joystick_direction_changed(direction: Vector2)

@onready var _joystick: DynamicJoystick = $DynamicJoystick
@onready var _inv_btn: Button           = $InventoryButton
@onready var _inv_icon: TextureRect     = $InventoryButton/Icon
@onready var _inv_panel: Node           = $InventoryPanel
@onready var _selected_slot: Panel      = $SelectedItemSlot
@onready var _selected_icon: TextureRect = $SelectedItemSlot/SelectedIcon
@onready var _deselect_btn: Button      = $SelectedItemSlot/DeselectBtn
@onready var _harvest_btn: Button       = $HarvestButton
# Add ShopButton (Button) to HUD.tscn in the Godot editor
@onready var _shop_btn: Button          = $ShopButton

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

func _on_joystick_direction(dir: Vector2) -> void:
	joystick_direction_changed.emit(dir)

func _toggle_inventory() -> void:
	if _inv_panel == null:
		return
	if _inv_panel.visible:
		_inv_panel.hide()
	else:
		_inv_panel.call("show_panel")

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

func _open_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/shop/ShopScene.tscn")
