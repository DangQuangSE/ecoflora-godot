class_name InventoryPanelNode
extends Control

const InventorySlotScene := preload("res://scenes/inventory/InventorySlot.tscn")

@onready var _bg_dimmer: ColorRect         = $BGDimmer
@onready var _close_btn: Button            = $PanelRoot/VBox/TitleBar/CloseBtn
@onready var _btn_all: Button              = $PanelRoot/VBox/Tabs/BtnAll
@onready var _btn_seed: Button             = $PanelRoot/VBox/Tabs/BtnSeed
@onready var _btn_item: Button             = $PanelRoot/VBox/Tabs/BtnItem
@onready var _btn_harvest: Button          = $PanelRoot/VBox/Tabs/BtnHarvest
@onready var _slot_grid: GridContainer     = $PanelRoot/VBox/Scroll/SlotGrid
@onready var _empty_label: Label           = $PanelRoot/VBox/Scroll/EmptyLabel

var _current_filter: int = -1

func _ready() -> void:
	_close_btn.pressed.connect(hide)
	_bg_dimmer.gui_input.connect(_on_dimmer_input)
	_btn_all.pressed.connect(func(): _set_filter(-1))
	_btn_seed.pressed.connect(func(): _set_filter(InventoryItem.Category.SEED))
	_btn_item.pressed.connect(func(): _set_filter(InventoryItem.Category.CONSUMABLE))
	_btn_harvest.pressed.connect(func(): _set_filter(InventoryItem.Category.HARVEST_PRODUCT))
	InventoryManager.inventory_updated.connect(_on_inventory_updated)
	visible = false

func show_panel() -> void:
	_refresh(InventoryManager.get_inventory())
	_update_tab_styles()
	visible = true

func _set_filter(category: int) -> void:
	_current_filter = category
	_update_tab_styles()
	_refresh(InventoryManager.get_inventory())

func _update_tab_styles() -> void:
	var btns  := [_btn_all, _btn_seed, _btn_item, _btn_harvest]
	var cats  := [-1, InventoryItem.Category.SEED,
				InventoryItem.Category.CONSUMABLE,
				InventoryItem.Category.HARVEST_PRODUCT]
	for i in range(btns.size()):
		btns[i].modulate = Color.WHITE if _current_filter == cats[i] else Color(1, 1, 1, 0.45)

func _on_inventory_updated(inventory: UserInventory) -> void:
	if visible:
		_refresh(inventory)

func _refresh(inventory: UserInventory) -> void:
	for child in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	var items := _get_filtered_items(inventory)
	_empty_label.visible = items.is_empty()
	for item: InventoryItem in items:
		var slot := InventorySlotScene.instantiate() as InventorySlotNode
		_slot_grid.add_child(slot)
		slot.setup(item, ItemIconRegistry.get_icon(item.get_reference_id()))

func _get_filtered_items(inventory: UserInventory) -> Array[InventoryItem]:
	var result: Array[InventoryItem] = []
	for item: InventoryItem in inventory.items:
		if item.quantity <= 0:
			continue
		if _current_filter == -1 or item.category == _current_filter:
			result.append(item)
	return result

func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide()
	elif event is InputEventScreenTouch and event.pressed:
		hide()
