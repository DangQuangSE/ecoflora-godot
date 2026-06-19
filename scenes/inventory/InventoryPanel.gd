class_name InventoryPanelNode
extends Control

const InventorySlotScene := preload("res://scenes/inventory/InventorySlot.tscn")

@onready var _bg_dimmer: ColorRect         = $BGDimmer
@onready var _close_btn: Button            = $PanelRoot/VBox/TitleBar/CloseBtn
@onready var _btn_all: Button              = $PanelRoot/VBox/Tabs/BtnAll
@onready var _btn_seed: Button             = $PanelRoot/VBox/Tabs/BtnSeed
@onready var _btn_item: Button             = $PanelRoot/VBox/Tabs/BtnItem
@onready var _btn_decor: Button            = $PanelRoot/VBox/Tabs/BtnDecor
@onready var _slot_grid: GridContainer     = $PanelRoot/VBox/Scroll/SlotGrid
@onready var _empty_label: Label           = $PanelRoot/VBox/Scroll/EmptyLabel

var _style_tab_normal := StyleBoxFlat.new()
var _style_tab_active := StyleBoxFlat.new()
var _style_tab_hover  := StyleBoxFlat.new()

var _current_filter: int = -1

func _ready() -> void:
	_build_tab_styles()
	_close_btn.pressed.connect(hide_panel)
	_bg_dimmer.gui_input.connect(_on_dimmer_input)
	_btn_all.pressed.connect(func(): _set_filter(-1))
	_btn_seed.pressed.connect(func(): _set_filter(InventoryItem.Category.SEED))
	_btn_item.pressed.connect(func(): _set_filter(InventoryItem.Category.CONSUMABLE))
	_btn_decor.pressed.connect(func(): _set_filter(InventoryItem.Category.DECOR))
	InventoryManager.inventory_updated.connect(_on_inventory_updated)
	GardenManager.icons_registered.connect(func():
		if visible:
			_refresh(InventoryManager.get_inventory()))
	visible = false

func _build_tab_styles() -> void:
	for s in [_style_tab_normal, _style_tab_active, _style_tab_hover]:
		s.corner_radius_top_left = 12
		s.corner_radius_top_right = 12
		s.border_width_left = 2
		s.border_width_top = 2
		s.border_width_right = 2
		s.border_width_bottom = 3
		s.border_color = Color(0.45, 0.27, 0.09, 1)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 7
		s.content_margin_bottom = 9
	_style_tab_normal.bg_color = Color(0.55, 0.32, 0.12, 1)
	_style_tab_hover.bg_color = Color(0.68, 0.43, 0.18, 1)
	_style_tab_active.bg_color = Color(1.0, 0.93, 0.74, 1)
	_style_tab_active.border_color = Color(0.78, 0.49, 0.16, 1)

func show_panel() -> void:
	_refresh(InventoryManager.get_inventory())
	_update_tab_styles()
	visible = true
	AudioManager.play_sfx("res://sounds/item_bag_click.wav")

func _set_filter(category: int) -> void:
	_current_filter = category
	_update_tab_styles()
	_refresh(InventoryManager.get_inventory())

func _update_tab_styles() -> void:
	var btns := [_btn_all, _btn_seed, _btn_item, _btn_decor]
	var cats := [-1, InventoryItem.Category.SEED, InventoryItem.Category.CONSUMABLE, InventoryItem.Category.DECOR]
	for i in range(btns.size()):
		var is_active: bool = (_current_filter == cats[i])
		var btn := btns[i] as Button
		btn.add_theme_stylebox_override("normal",  _style_tab_active if is_active else _style_tab_normal)
		btn.add_theme_stylebox_override("pressed", _style_tab_active)
		btn.add_theme_stylebox_override("hover",   _style_tab_active if is_active else _style_tab_hover)
		btn.add_theme_color_override("font_color",
			Color(0.61, 0.31, 0.07, 1) if is_active else Color(0.97, 0.86, 0.60, 1))
		btn.add_theme_color_override("font_hover_color",
			Color(0.61, 0.31, 0.07, 1) if is_active else Color(0.97, 0.86, 0.60, 1))
		btn.add_theme_color_override("font_pressed_color",
			Color(0.61, 0.31, 0.07, 1))
		btn.add_theme_constant_override("outline_size", 2 if is_active else 1)
		btn.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.95))

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

func hide_panel() -> void:
	if visible:
		AudioManager.play_sfx("res://sounds/item_bag_click.wav")
		hide()

func _on_dimmer_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_panel()
	elif event is InputEventScreenTouch and event.pressed:
		hide_panel()
