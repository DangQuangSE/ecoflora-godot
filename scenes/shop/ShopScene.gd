class_name ShopScene
extends Control

const ShopItemCardScene := preload("res://scenes/shop/ShopItemCard.tscn")
var _style_tab_normal  := StyleBoxFlat.new()
var _style_tab_active  := StyleBoxFlat.new()
var _style_tab_hover   := StyleBoxFlat.new()

const _MOCK := {
	0: [],
	1: [],
	2: [],
}

@onready var _grid: GridContainer        = $ShopPanel/ScrollContainer/GridContainer
@onready var _spinner: Control           = $LoadingSpinner
@onready var _confirm_overlay: ColorRect = $ConfirmOverlay
@onready var _confirm_dialog: Control    = $ConfirmDialog
@onready var _confirm_name: Label        = $ConfirmDialog/VBox/ItemNameLabel
@onready var _confirm_desc: Label        = $ConfirmDialog/VBox/ItemDescLabel
@onready var _confirm_price: Label       = $ConfirmDialog/VBox/PriceRow/PriceLabel
@onready var _confirm_balance: Label     = $ConfirmDialog/VBox/PriceRow/BalanceHint
@onready var _qty_minus: Button          = $ConfirmDialog/VBox/QuantityRow/MinusButton
@onready var _qty_label: Label           = $ConfirmDialog/VBox/QuantityRow/QuantityLabel
@onready var _qty_plus: Button           = $ConfirmDialog/VBox/QuantityRow/PlusButton
@onready var _total_label: Label         = $ConfirmDialog/VBox/TotalRow/TotalLabel
@onready var _confirm_btn: Button        = $ConfirmDialog/VBox/ButtonRow/ConfirmButton
@onready var _cancel_btn: Button         = $ConfirmDialog/VBox/ButtonRow/CancelButton
@onready var _toast: Panel               = $ToastNotification
@onready var _toast_label: Label         = $ToastNotification/ToastLabel

var _tab_btns: Array = []
var _pending_item: ShopItem = null
var _pending_qty: int = 1
var _toast_tween: Tween = null

var _style_toast_ok  := StyleBoxFlat.new()
var _style_toast_err := StyleBoxFlat.new()

func _ready() -> void:
	_build_tab_styles()
	_build_toast_styles()
	_tab_btns = [
		$ShopPanel/ShopBg/TabGroup/HatGiongBtn,
		$ShopPanel/ShopBg/TabGroup/CongCuBtn,
		$ShopPanel/ShopBg/TabGroup/CoinBtn,
	]
	for i in _tab_btns.size():
		var idx := i
		var btn := _tab_btns[i] as Button
		btn.pressed.connect(func() -> void: _on_tab_pressed(idx))
		btn.add_theme_constant_override("outline_size", 2)
		btn.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.01, 0.95))
	_confirm_btn.pressed.connect(_on_confirm_purchase)
	_cancel_btn.pressed.connect(_hide_dialog)
	_confirm_overlay.gui_input.connect(_on_overlay_input)
	_qty_minus.pressed.connect(_on_qty_minus)
	_qty_plus.pressed.connect(_on_qty_plus)
	_confirm_dialog.hide()
	_confirm_overlay.hide()
	_toast.hide()
	var open_tab: int = UserManager.shop_open_tab
	UserManager.shop_open_tab = 0
	_on_tab_pressed(open_tab)

func _build_tab_styles() -> void:
	for s in [_style_tab_normal, _style_tab_active, _style_tab_hover]:
		s.corner_radius_top_left  = 8
		s.corner_radius_top_right = 8
		s.border_width_left  = 1
		s.border_width_top   = 1
		s.border_width_right = 1
	_style_tab_normal.bg_color    = Color(0.40, 0.24, 0.10, 1)
	_style_tab_normal.border_color = Color(0.62, 0.44, 0.24, 1)
	_style_tab_active.bg_color    = Color(0.76, 0.55, 0.30, 1)
	_style_tab_active.border_color = Color(0.95, 0.78, 0.50, 1)
	_style_tab_active.border_width_top = 2
	_style_tab_hover.bg_color     = Color(0.52, 0.34, 0.16, 1)
	_style_tab_hover.border_color  = Color(0.72, 0.52, 0.30, 1)

func _build_toast_styles() -> void:
	for style in [_style_toast_ok, _style_toast_err]:
		style.corner_radius_top_left    = 12
		style.corner_radius_top_right   = 12
		style.corner_radius_bottom_right = 12
		style.corner_radius_bottom_left  = 12
	_style_toast_ok.bg_color  = Color(0.15, 0.45, 0.1, 0.95)
	_style_toast_err.bg_color = Color(0.5, 0.1, 0.08, 0.95)

func _on_tab_pressed(idx: int) -> void:
	_set_active_tab(idx)
	_render_items(_MOCK.get(idx, []))

func _set_active_tab(idx: int) -> void:
	for i in _tab_btns.size():
		var btn := _tab_btns[i] as Button
		var is_active := i == idx
		btn.add_theme_stylebox_override("normal",   _style_tab_active if is_active else _style_tab_normal)
		btn.add_theme_stylebox_override("pressed",  _style_tab_active)
		btn.add_theme_stylebox_override("hover",    _style_tab_active if is_active else _style_tab_hover)
		btn.add_theme_color_override("font_color",
			Color(0.18, 0.09, 0.02, 1) if is_active else Color(1.0, 0.92, 0.72, 1))

func _render_items(items: Array) -> void:
	for child in _grid.get_children():
		child.queue_free()
	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "Sắp ra mắt..."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.55, 1))
		_grid.call_deferred("add_child", lbl)
		return
	var balance: int = UserManager.get_profile().currency
	for d in items:
		var item := ShopItem.new()
		item.id        = str(d.get("id", ""))
		item.name      = str(d.get("name", ""))
		item.price     = int(d.get("price", 0))
		item.image_url = str(d.get("icon_path", ""))
		item.is_active = true
		var card: ShopItemCard = ShopItemCardScene.instantiate()
		_grid.add_child(card)
		card.setup(item, balance)
		card.tapped.connect(_on_item_tapped)

func _refresh_card_affordability() -> void:
	var balance: int = UserManager.get_profile().currency
	for child in _grid.get_children():
		if child is ShopItemCard:
			(child as ShopItemCard).set_affordable(balance >= (child as ShopItemCard).item_price())

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
