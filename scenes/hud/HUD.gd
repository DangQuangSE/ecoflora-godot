class_name HUD
extends CanvasLayer

signal joystick_direction_changed(direction: Vector2)

@onready var _joystick: DynamicJoystick       = $DynamicJoystick
@onready var _inv_btn: Button                 = $InventoryButton
@onready var _inv_icon: TextureRect           = $InventoryButton/Icon
@onready var _inv_panel: InventoryPanelNode   = $InventoryPanel
@onready var _selected_slot: Panel            = $SelectedItemSlot
@onready var _selected_icon: TextureRect      = $SelectedItemSlot/SelectedIcon
@onready var _deselect_btn: Button            = $SelectedItemSlot/DeselectBtn

func _ready() -> void:
	_joystick.direction_changed.connect(_on_joystick_direction)
	_inv_btn.pressed.connect(_toggle_inventory)
	_deselect_btn.pressed.connect(InventoryManager.deselect)
	InventoryManager.item_selected.connect(_on_item_selected)
	_inv_icon.texture = preload("res://assets/icon/bag.png")
	_selected_slot.visible = false

func _on_joystick_direction(dir: Vector2) -> void:
	joystick_direction_changed.emit(dir)

func _toggle_inventory() -> void:
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
	if _inv_panel.visible:
		_inv_panel.hide()
