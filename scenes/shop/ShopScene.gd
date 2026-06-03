class_name ShopScene
extends Control

# Required nodes in ShopScene.tscn:
# - BackButton (Button)
# - TabContainer with tabs: Consumables, Seeds, Decorations
#   Each tab: ScrollContainer → GridContainer
# - LoadingSpinner (Control or AnimatedSprite2D)
# - ConfirmDialog (AcceptDialog or Panel)
#   - ConfirmDialog/ItemNameLabel (Label)
#   - ConfirmDialog/PriceLabel (Label)
#   - ConfirmDialog/ConfirmButton (Button)
#   - ConfirmDialog/CancelButton (Button)

const ShopItemCardScene := preload("res://scenes/shop/ShopItemCard.tscn")
const DEFAULT_PURCHASE_QTY: int = 1

@onready var _back_btn: Button         = $BackButton
@onready var _tab_container: TabContainer = $TabContainer
@onready var _spinner: Control         = $LoadingSpinner
@onready var _confirm_dialog: Control  = $ConfirmDialog
@onready var _confirm_name: Label      = $ConfirmDialog/ItemNameLabel
@onready var _confirm_price: Label     = $ConfirmDialog/PriceLabel
@onready var _confirm_btn: Button      = $ConfirmDialog/ConfirmButton
@onready var _cancel_btn: Button       = $ConfirmDialog/CancelButton

var _catalog: Array[ShopItem] = []
var _pending_item: ShopItem = null
var _tab_grids: Array[GridContainer] = []

func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_confirm_btn.pressed.connect(_on_confirm_purchase)
	_cancel_btn.pressed.connect(func() -> void: _confirm_dialog.hide())
	_confirm_dialog.hide()
	_tab_container.tab_changed.connect(_on_tab_changed)
	_cache_grids()
	_load_catalog()

func _cache_grids() -> void:
	# Assumes tabs are ordered: Consumables(0), Seeds(1), Decorations(2)
	for i in _tab_container.get_tab_count():
		var scroll: ScrollContainer = _tab_container.get_tab_control(i) as ScrollContainer
		if scroll:
			var grid: GridContainer = scroll.get_child(0) as GridContainer
			if grid:
				_tab_grids.append(grid)

func _load_catalog() -> void:
	_spinner.show()
	_catalog = await UserManager.get_shop_catalog_async()
	_spinner.hide()
	if _catalog.is_empty():
		push_warning("ShopScene: catalog returned empty — check server or network")
	_populate_tab(_tab_container.current_tab)

func _populate_tab(tab_idx: int) -> void:
	if tab_idx >= _tab_grids.size():
		return
	var grid: GridContainer = _tab_grids[tab_idx]
	for child in grid.get_children():
		child.queue_free()

	var category: String = ["Consumable", "Seed", "Decoration"][tab_idx]

	if category == "Decoration":
		var lbl := Label.new()
		lbl.text = "Sắp ra mắt..."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(lbl)
		return

	var filtered := _catalog.filter(func(i: ShopItem) -> bool: return i.category == category)
	for item: ShopItem in filtered:
		var card: ShopItemCard = ShopItemCardScene.instantiate()
		grid.add_child(card)
		card.setup(item)
		card.tapped.connect(_on_item_tapped)

func _on_tab_changed(tab_idx: int) -> void:
	_populate_tab(tab_idx)

func _on_item_tapped(item: ShopItem) -> void:
	_pending_item = item
	_confirm_name.text = item.name
	var balance: int = UserManager.get_profile().currency
	_confirm_price.text = "%d 🪙 (số dư: %d)" % [item.price, balance]
	_confirm_btn.disabled = balance < item.price
	_confirm_dialog.show()

func _on_confirm_purchase() -> void:
	if _pending_item == null:
		return
	_confirm_dialog.hide()
	_confirm_btn.disabled = true
	var result: Dictionary = await UserManager.purchase_async(_pending_item.id, DEFAULT_PURCHASE_QTY)
	_confirm_btn.disabled = false
	_pending_item = null
	if result.is_empty():
		push_warning("ShopScene: purchase failed")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/garden/GardenScene.tscn")
