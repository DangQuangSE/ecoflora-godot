class_name ShopScene
extends Control

const ShopItemCardScene := preload("res://scenes/shop/ShopItemCard.tscn")

@onready var _back_btn: Button            = $Header/BackButton
@onready var _balance_label: Label        = $Header/CurrencyBox/BalanceLabel
@onready var _tab_container: TabContainer = $TabContainer
@onready var _spinner: Control            = $LoadingSpinner
@onready var _confirm_overlay: ColorRect  = $ConfirmOverlay
@onready var _confirm_dialog: Control     = $ConfirmDialog
@onready var _confirm_name: Label         = $ConfirmDialog/VBox/ItemNameLabel
@onready var _confirm_desc: Label         = $ConfirmDialog/VBox/ItemDescLabel
@onready var _confirm_price: Label        = $ConfirmDialog/VBox/PriceRow/PriceLabel
@onready var _confirm_balance: Label      = $ConfirmDialog/VBox/PriceRow/BalanceHint
@onready var _qty_minus: Button           = $ConfirmDialog/VBox/QuantityRow/MinusButton
@onready var _qty_label: Label            = $ConfirmDialog/VBox/QuantityRow/QuantityLabel
@onready var _qty_plus: Button            = $ConfirmDialog/VBox/QuantityRow/PlusButton
@onready var _total_label: Label          = $ConfirmDialog/VBox/TotalRow/TotalLabel
@onready var _confirm_btn: Button         = $ConfirmDialog/VBox/ButtonRow/ConfirmButton
@onready var _cancel_btn: Button          = $ConfirmDialog/VBox/ButtonRow/CancelButton
@onready var _toast: Panel                = $ToastNotification
@onready var _toast_label: Label          = $ToastNotification/ToastLabel

var _catalog: Array[ShopItem] = []
var _pending_item: ShopItem = null
var _pending_qty: int = 1
var _tab_grids: Array[GridContainer] = []
var _toast_tween: Tween = null

var _style_toast_ok := StyleBoxFlat.new()
var _style_toast_err := StyleBoxFlat.new()

func _ready() -> void:
	_build_toast_styles()
	_back_btn.pressed.connect(_on_back)
	_confirm_btn.pressed.connect(_on_confirm_purchase)
	_cancel_btn.pressed.connect(_hide_dialog)
	_confirm_overlay.gui_input.connect(_on_overlay_input)
	_qty_minus.pressed.connect(_on_qty_minus)
	_qty_plus.pressed.connect(_on_qty_plus)
	_confirm_dialog.hide()
	_confirm_overlay.hide()
	_toast.hide()
	_tab_container.tab_changed.connect(_on_tab_changed)
	_cache_grids()
	var open_tab: int = UserManager.shop_open_tab
	UserManager.shop_open_tab = 0
	_tab_container.current_tab = open_tab
	_refresh_balance_label()
	_load_catalog()

func _build_toast_styles() -> void:
	for style in [_style_toast_ok, _style_toast_err]:
		style.corner_radius_top_left    = 12
		style.corner_radius_top_right   = 12
		style.corner_radius_bottom_right = 12
		style.corner_radius_bottom_left  = 12
	_style_toast_ok.bg_color  = Color(0.15, 0.45, 0.1, 0.95)
	_style_toast_err.bg_color = Color(0.5, 0.1, 0.08, 0.95)

func _cache_grids() -> void:
	for i in _tab_container.get_tab_count():
		var scroll := _tab_container.get_tab_control(i) as ScrollContainer
		if scroll:
			var grid := scroll.get_child(0) as GridContainer
			if grid:
				_tab_grids.append(grid)

func _refresh_balance_label() -> void:
	_balance_label.text = str(UserManager.get_profile().currency)

func _load_catalog() -> void:
	_spinner.show()
	_catalog = await UserManager.get_shop_catalog_async()
	_spinner.hide()
	if _catalog.is_empty():
		push_warning("ShopScene: catalog returned empty")
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
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.55, 1))
		grid.add_child(lbl)
		return

	var balance: int = UserManager.get_profile().currency
	var filtered := _catalog.filter(func(i: ShopItem) -> bool: return i.category == category)
	for item: ShopItem in filtered:
		var card: ShopItemCard = ShopItemCardScene.instantiate()
		grid.add_child(card)
		card.setup(item, balance)
		card.tapped.connect(_on_item_tapped)

func _refresh_card_affordability() -> void:
	var balance: int = UserManager.get_profile().currency
	for grid in _tab_grids:
		for child in grid.get_children():
			if child is ShopItemCard:
				(child as ShopItemCard).set_affordable(balance >= (child as ShopItemCard).item_price())

func _on_tab_changed(tab_idx: int) -> void:
	_populate_tab(tab_idx)

func _on_item_tapped(item: ShopItem) -> void:
	_pending_item = item
	_pending_qty = 1
	_confirm_name.text = item.name
	_confirm_desc.text = item.description
	_confirm_price.text = str(item.price)
	_confirm_balance.text = " (số dư: %d)" % UserManager.get_profile().currency
	_qty_label.text = "1"
	_update_dialog_total()
	_confirm_overlay.show()
	_confirm_dialog.show()

func _update_dialog_total() -> void:
	if _pending_item == null:
		return
	var total: int = _pending_item.price * _pending_qty
	_total_label.text = "Tổng: %d" % total
	_confirm_btn.disabled = UserManager.get_profile().currency < total

func _on_qty_minus() -> void:
	if _pending_qty <= 1:
		return
	_pending_qty -= 1
	_qty_label.text = str(_pending_qty)
	_update_dialog_total()

func _on_qty_plus() -> void:
	_pending_qty += 1
	_qty_label.text = str(_pending_qty)
	_update_dialog_total()

func _hide_dialog() -> void:
	_confirm_dialog.hide()
	_confirm_overlay.hide()

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_hide_dialog()

func _on_confirm_purchase() -> void:
	if _pending_item == null:
		return
	var item := _pending_item
	var qty  := _pending_qty
	_hide_dialog()
	_confirm_btn.disabled = true
	var result: Dictionary = await UserManager.purchase_async(item.id, qty)
	_confirm_btn.disabled = false
	_pending_item = null
	if result.is_empty():
		_show_toast("Mua thất bại!", false)
	else:
		_show_toast("Đã mua %s ×%d!" % [item.name, qty], true)
		_refresh_balance_label()
		_refresh_card_affordability()

func _show_toast(message: String, success: bool) -> void:
	_toast_label.text = message
	_toast.add_theme_stylebox_override("panel", _style_toast_ok if success else _style_toast_err)
	_toast.modulate.a = 1.0
	_toast.show()
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/garden/GardenScene.tscn")
